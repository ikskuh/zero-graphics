//! This file must export the following functions:
//! - `pub fn init(app: *Application, allocator: std.mem.Allocator) !void`
//! - `pub fn update(app: *Application) !bool`
//! - `pub fn render(app: *Application) !void`
//! - `pub fn deinit(app: *Application) void`
//!
//! This file *can* export the following functions:
//! - `pub fn setupGraphics(app: *Application) !void`
//! - `pub fn resize(app: *Application, width: u15, height: u15) !void`
//! - `pub fn teardownGraphics(app: *Application) void`
//!

const std = @import("std");
const builtin = @import("builtin");
const zero_graphics = @import("zero-graphics");
const zero_ui = @import("zero-ui");
const layout_engine = @import("layout-engine");
const render_engine = @import("render-engine");

const logger = std.log.scoped(.ui_demo);

const core = zero_graphics.CoreApplication.get;

const Application = @This();

core_view: zero_ui.View = undefined,
widget_pool: zero_ui.MemoryPool(zero_ui.Widget) = undefined,

renderer2d: zero_graphics.Renderer2D,
gui_renderer: render_engine.Renderer,

pub fn init(app: *Application) !void {
    app.* = Application{
        .renderer2d = undefined,
        .gui_renderer = undefined,
    };

    logger.info("available controls:", .{});
    for (std.enums.values(zero_ui.controls.ClassID)) |class_id| {
        logger.info("- {s}", .{@tagName(class_id)});
    }

    app.printWidgetTree();

    app.renderer2d = try core().resources.createRenderer2D();
    errdefer app.renderer2d.deinit();

    app.gui_renderer = try render_engine.Renderer.init(&app.renderer2d);
    errdefer app.gui_renderer.deinit();

    const app_logo = try app.gui_renderer.createImage(@embedFile("logo.png"));
    errdefer app.gui_renderer.destroyImage(app_logo);

    // Construct the following ui sketch:
    //
    // +---------------------------------------------------------+
    // |                                                         |
    // |                                                         |
    // |                                                         |
    // |               +-------------------------+               |
    // |               |                         |               |
    // |               |        /^^^^^^\         |               |
    // |               |        | Logo |         |               |
    // |               |        \______/         |               |
    // |               |                         |               |
    // |               | Username: [           ] |               |
    // |               | Password: [           ] |               |
    // |               |                         |               |
    // |               | [Cancel]        [Login] |               |
    // |               |                         |               |
    // |               +-------------------------+               |
    // |                                                         |
    // |                                                         |
    // |                                                         |
    // +---------------------------------------------------------+
    //
    //
    const ui_data = blk: {
        var builder = zero_ui.Builder.begin(core().allocator);
        errdefer builder.cancel();

        _ = try builder.add(.{
            .Panel = .{},
        });
        builder.current().setBounds(.{ .x = (480 - 318) / 2, .y = (320 - 284) / 2, .width = 318, .height = 284 });

        {
            try builder.enter();
            defer builder.leave();

            _ = try builder.add(.{
                .Picture = .{
                    .image = app_logo,
                },
            });
            builder.current().setBounds(.{ .x = 126, .y = 13, .width = 66, .height = 67 });

            _ = try builder.add(.{
                .Label = .{
                    .text = "Username:",
                    .vertical_alignment = .center,
                    .horizontal_alignment = .right,
                },
            });
            builder.current().setBounds(.{ .x = 41, .y = 95, .width = 75, .height = 42 });

            _ = try builder.add(.{
                .TextBox = .{},
            });
            builder.current().setBounds(.{ .x = 120, .y = 95, .width = 157, .height = 42 });

            _ = try builder.add(.{
                .Label = .{
                    .text = "Password:",
                    .vertical_alignment = .center,
                    .horizontal_alignment = .right,
                },
            });
            builder.current().setBounds(.{ .x = 41, .y = 153, .width = 75, .height = 42 });

            _ = try builder.add(.{
                .TextBox = .{ .flags = .{ .password = true } },
            });
            builder.current().setBounds(.{ .x = 120, .y = 153, .width = 157, .height = 42 });

            _ = try builder.add(.{
                .Button = .{ .text = "Cancel" },
            });
            builder.current().setBounds(.{ .x = 15, .y = 208, .width = 115, .height = 31 });

            _ = try builder.add(.{
                .Button = .{ .text = "Login" },
            });
            builder.current().setBounds(.{ .x = 190, .y = 208, .width = 115, .height = 31 });
        }

        break :blk builder.finish();
    };

    app.core_view = ui_data.view;
    app.widget_pool = ui_data.memory;
    errdefer app.widget_pool.deinit();
}

pub fn deinit(app: *Application) void {
    app.gui_renderer.deinit();
    app.renderer2d.deinit();
    app.widget_pool.deinit();
    app.* = undefined;
}

fn printWidgetTree(app: *Application) void {
    return printWidgetTreeInner(app, app.core_view.widgets, 0);
}
fn printWidgetTreeInner(app: *Application, list: zero_ui.Widget.List, depth: usize) void {
    var out = std.io.getStdOut().writer();

    var it = list.first;
    while (it) |node| : (it = node.next) {
        const widget = zero_ui.Widget.fromNode(node);

        out.writeByteNTimes(' ', 2 * depth) catch {};
        out.print("- {s}\n", .{@tagName(widget.control)}) catch {};

        app.printWidgetTreeInner(widget.children, depth + 1);
    }
}

pub fn update(app: *Application) !bool {
    while (core().input.fetch()) |event| {
        switch (event) {
            .quit => return false,
            .pointer_motion => |pos| app.core_view.pushInput(.{ .mouse_motion = pos }),
            .pointer_press => |btn| app.core_view.pushInput(.{ .mouse_button_down = btn }),
            .pointer_release => |btn| app.core_view.pushInput(.{ .mouse_button_up = btn }),
            .text_input => |input| app.core_view.pushInput(.{ .text_input = input.text }),
            .key_down => |key| if (key == .escape) {
                return false;
            } else {
                app.core_view.pushInput(.{ .key_down = .{ .scancode = @enumToInt(key), .key = key } });
            },
            .key_up => |key| app.core_view.pushInput(.{ .key_up = .{ .scancode = @enumToInt(key), .key = key } }),
        }

        while (app.core_view.pullEvent()) |ui_event| {
            logger.info("received ui event: {}", .{ui_event});
        }
    }

    app.renderer2d.reset();

    try app.renderer2d.drawRectangle(.{
        .x = 0,
        .y = 0,
        .width = 480,
        .height = 320,
    }, zero_graphics.Color.white);

    try app.gui_renderer.render(app.core_view, core().screen_size);

    return true;
}

pub fn render(app: *Application) !void {
    const gl = zero_graphics.gles;

    gl.clearColor(0.0, 0.0, 0.5, 1.0);
    gl.clearDepthf(1.0);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

    app.renderer2d.render(core().screen_size);
}
