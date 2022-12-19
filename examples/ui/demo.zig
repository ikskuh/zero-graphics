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

const logger = std.log.scoped(.ui_demo);

const core = zero_graphics.CoreApplication.get;

const Application = @This();

core_view: zero_ui.View = undefined,
widget_pool: zero_ui.MemoryPool(zero_ui.Widget) = undefined,

pub fn init(app: *Application) !void {
    app.* = Application{};

    logger.info("available controls:", .{});
    for (std.enums.values(zero_ui.controls.ClassID)) |class_id| {
        logger.info("- {s}", .{@tagName(class_id)});
    }

    const ui_data = blk: {
        var builder = zero_ui.Builder.begin(core().allocator);
        errdefer builder.cancel();

        _ = try builder.add(zero_ui.Widget{
            .control = .{
                .Panel = .{},
            },
        });

        {
            try builder.enter();
            defer builder.leave();

            _ = try builder.add(zero_ui.Widget{
                .control = .{
                    .Picture = .{},
                },
            });

            _ = try builder.add(zero_ui.Widget{
                .control = .{
                    .Label = .{},
                },
            });
            _ = try builder.add(zero_ui.Widget{
                .control = .{
                    .TextBox = .{},
                },
            });

            _ = try builder.add(zero_ui.Widget{
                .control = .{
                    .Label = .{},
                },
            });
            _ = try builder.add(zero_ui.Widget{
                .control = .{
                    .TextBox = .{},
                },
            });

            _ = try builder.add(zero_ui.Widget{
                .control = .{
                    .Button = .{ .text = "Cancel" },
                },
            });

            _ = try builder.add(zero_ui.Widget{
                .control = .{
                    .Button = .{ .text = "Login" },
                },
            });
        }

        break :blk builder.finish();
    };

    app.core_view = ui_data.view;
    app.widget_pool = ui_data.memory;
    errdefer app.widget_pool.deinit();

    app.printWidgetTree();
}

pub fn deinit(app: *Application) void {
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

    // TODO: process input events here:
    while (core().input.fetch()) |event| {
        switch (event) {
            .quit => return false,
            .pointer_motion => {},
            .pointer_press => {},
            .pointer_release => {},
            .text_input => {},
            .key_down => {},
            .key_up => {},
        }
    }

    _ = app;

    return true;
}

pub fn render(app: *Application) !void {
    const gl = zero_graphics.gles;

    gl.clearColor(0.3, 0.3, 0.3, 1.0);
    gl.clearDepthf(1.0);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

    // Render your application here
    _ = app;
}
