//! This file must export the following functions:
//! - `pub fn init(app: *Application, allocator: *std.mem.Allocator) !void`
//! - `pub fn setupGraphics(app: *Application) !void`
//! - `pub fn resize(app: *Application, width: u15, height: u15) !void`
//! - `pub fn update(app: *Application) !bool`
//! - `pub fn render(app: *Application) !void`
//! - `pub fn teardownGraphics(app: *Application) void`
//! - `pub fn deinit(app: *Application) void`
//!

const std = @import("std");
const builtin = @import("builtin");
const zlm = @import("zlm");
const zero_graphics = @import("zero-graphics");

const logger = std.log.scoped(.demo);
const gles = zero_graphics.gles;

const ResourceManager = zero_graphics.ResourceManager;
const Renderer = zero_graphics.Renderer2D;
const Renderer3D = zero_graphics.Renderer3D;

const Application = @This();

screen_width: u15,
screen_height: u15,
resources: ResourceManager,
renderer: Renderer,
texture_handle: *ResourceManager.Texture,
allocator: *std.mem.Allocator,
font: *const Renderer.Font,
input: *zero_graphics.Input,

ui: zero_graphics.UserInterface,

gui_data: DemoGuiData = .{},

renderer3d: Renderer3D,
mesh: *ResourceManager.Geometry,

startup_time: i64,

pub fn init(app: *Application, allocator: *std.mem.Allocator, input: *zero_graphics.Input) !void {
    app.* = Application{
        .allocator = allocator,
        .screen_width = 0,
        .screen_height = 0,
        .resources = ResourceManager.init(allocator),
        .texture_handle = undefined,
        .renderer = undefined,
        .ui = undefined,
        .font = undefined,
        .input = input,

        .renderer3d = undefined,
        .mesh = undefined,

        .startup_time = zero_graphics.milliTimestamp(),
    };
    errdefer app.resources.deinit();

    app.ui = try zero_graphics.UserInterface.init(app.allocator, null);
    errdefer app.ui.deinit();

    app.renderer = try app.resources.createRenderer2D();
    errdefer app.renderer.deinit();

    app.texture_handle = try app.resources.createTexture(.ui, ResourceManager.DecodePng{ .data = @embedFile("ziggy.png") });
    app.font = try app.renderer.createFont(@embedFile("GreatVibes-Regular.ttf"), 48);

    app.renderer3d = try app.resources.createRenderer3D();
    errdefer app.renderer3d.deinit();

    try app.ui.setRenderer(&app.renderer);

    // app.mesh = try app.resources.createGeometry(ResourceManager.StaticMesh{
    //     .vertices = &.{
    //         .{ .x = 0, .y = 0, .z = 0, .nx = 0, .ny = 0, .nz = 0, .u = 0, .v = 0 },
    //         .{ .x = 1, .y = 0, .z = 0, .nx = 0, .ny = 0, .nz = 0, .u = 1, .v = 0 },
    //         .{ .x = 0, .y = 0, .z = 1, .nx = 0, .ny = 0, .nz = 0, .u = 0, .v = 1 },
    //     },
    //     .indices = &.{ 0, 1, 2 },
    //     .texture = app.texture_handle,
    // });

    const TextureLoader = struct {
        pub fn load(self: @This(), rm: *ResourceManager, file_name: []const u8) !*ResourceManager.Texture {
            _ = self;
            if (std.mem.eql(u8, file_name, "metal-01.png"))
                return try rm.createTexture(.@"3d", ResourceManager.DecodePng{ .data = @embedFile("data/metal-01.png") });
            if (std.mem.eql(u8, file_name, "metal-02.png"))
                return try rm.createTexture(.@"3d", ResourceManager.DecodePng{ .data = @embedFile("data/metal-02.png") });
            return error.FileNotFound;
        }
    };
    app.mesh = try app.resources.createGeometry(ResourceManager.Z3DGeometry(TextureLoader){
        .data = @embedFile("twocubes.z3d"),
        .loader = .{},
    });
}

pub fn deinit(app: *Application) void {
    app.ui.deinit();
    app.* = undefined;
}

pub fn setupGraphics(app: *Application) !void {
    {
        logger.info("OpenGL Version:       {s}", .{std.mem.span(gles.getString(gles.VERSION))});
        logger.info("OpenGL Vendor:        {s}", .{std.mem.span(gles.getString(gles.VENDOR))});
        logger.info("OpenGL Renderer:      {s}", .{std.mem.span(gles.getString(gles.RENDERER))});
        logger.info("OpenGL GLSL:          {s}", .{std.mem.span(gles.getString(gles.SHADING_LANGUAGE_VERSION))});
    }

    logger.info("Display density: {d:.3} DPI", .{zero_graphics.getDisplayDPI()});

    // If possible, install the debug callback in debug builds
    if (builtin.mode == .Debug) {
        zero_graphics.gles_utils.enableDebugOutput() catch {};
    }

    try app.resources.initializeGpuData();
}

pub fn teardownGraphics(app: *Application) void {
    app.resources.destroyGpuData();
}

pub fn resize(app: *Application, width: u15, height: u15) !void {
    if (width != app.screen_width or height != app.screen_height) {
        logger.info("screen resized to resolution: {}×{}", .{ width, height });
        app.screen_width = @intCast(u15, width);
        app.screen_height = @intCast(u15, height);
    }
}

pub fn update(app: *Application) !bool {
    {
        var ui_input = app.ui.processInput();
        while (app.input.pollEvent()) |event| {
            switch (event) {
                .quit => return false,

                .pointer_motion => |pt| ui_input.setPointer(pt),
                .pointer_press => ui_input.pointerDown(),
                .pointer_release => |cursor| ui_input.pointerUp(switch (cursor) {
                    .primary => zero_graphics.UserInterface.Pointer.primary,
                    .secondary => .secondary,
                }),

                .text_input => |text| {
                    std.log.info("text_input: '{}' ({})", .{
                        std.fmt.fmtSliceEscapeUpper(text.text), // escape special chars here
                        text.modifiers,
                    });
                    try ui_input.enterText(text.text);
                },

                .key_down => |scancode| std.log.info("key_down: {s}", .{@tagName(scancode)}),
                .key_up => |scancode| std.log.info("key_up: {s}", .{@tagName(scancode)}),
            }
        }
        ui_input.finish();
    }

    {
        var ui = app.ui.construct(.{
            .width = app.screen_width,
            .height = app.screen_height,
        });

        if (try ui.checkBox(.{ .x = 100, .y = 10, .width = 30, .height = 30 }, app.gui_data.is_visible, .{}))
            app.gui_data.is_visible = !app.gui_data.is_visible;

        if (app.gui_data.is_visible) {
            var fmt_buf: [64]u8 = undefined;

            try ui.panel(zero_graphics.Rectangle{
                .x = 150,
                .y = 10,
                .width = 450,
                .height = 280,
            }, .{});

            for (app.gui_data.check_group) |*checked, i| {
                var rect = zero_graphics.Rectangle{
                    .x = 160,
                    .y = 20 + 40 * @intCast(u15, i),
                    .height = 30,
                    .width = 30,
                };
                if (try ui.checkBox(rect, checked.*, .{ .id = i }))
                    checked.* = !checked.*;

                rect.x += 40;
                rect.width = 80;
                try ui.label(rect, try std.fmt.bufPrint(&fmt_buf, "CheckBox {}", .{i}), .{ .id = i });

                rect.x += 100;
                rect.width = 30;

                if (try ui.radioButton(rect, (app.gui_data.radio_group_1 == i), .{ .id = i }))
                    app.gui_data.radio_group_1 = i;

                rect.x += 40;
                rect.width = 80;
                try ui.label(rect, try std.fmt.bufPrint(&fmt_buf, "RadioGroup 1.{}", .{i}), .{ .id = i });

                rect.x += 100;
                rect.width = 30;

                if (try ui.radioButton(rect, (app.gui_data.radio_group_2 == i), .{ .id = i }))
                    app.gui_data.radio_group_2 = i;

                rect.x += 40;
                rect.width = 80;
                try ui.label(rect, try std.fmt.bufPrint(&fmt_buf, "RadioGroup 2.{}", .{i}), .{ .id = i });
            }

            //            radio_group_1
            //radio_group_2
            //check_group
            {
                var i: u15 = 0;
                while (i < 3) : (i += 1) {
                    const rect = zero_graphics.Rectangle{
                        .x = 160 + 50 * i,
                        .y = 200 + 20 * i,
                        .width = 100,
                        .height = 40,
                    };
                    const clicked = try ui.button(rect, "Click me!", null, .{
                        .id = i,
                        .text_color = if ((app.gui_data.last_button orelse 9999) == i)
                            zero_graphics.Color{ .r = 0xFF, .g = 0x00, .b = 0x00 }
                        else
                            zero_graphics.Color.white,
                    });
                    if (clicked) {
                        if (app.gui_data.last_button) |btn| {
                            if (btn == i) {
                                app.gui_data.last_button = null;
                            } else {
                                app.gui_data.last_button = i;
                            }
                        } else {
                            app.gui_data.last_button = i;
                        }
                        logger.info("Button {} was clicked!", .{i});
                    }
                }
            }

            const CustomWidget = struct {
                var startup_time: ?i64 = null;
                var mouse_in: bool = false;
                var mouse_down: bool = false;

                pub fn update(self: zero_graphics.UserInterface.CustomWidget, event: zero_graphics.UserInterface.CustomWidget.Event) ?usize {
                    _ = self;
                    logger.info("custom widget received event: {}", .{event});
                    switch (event) {
                        .pointer_enter => mouse_in = true,
                        .pointer_leave => mouse_in = false,
                        .pointer_press => mouse_down = true,
                        .pointer_release => mouse_down = false,
                        .pointer_motion => {},
                    }
                    return null;
                }

                pub fn draw(self: zero_graphics.UserInterface.CustomWidget, rectangle: zero_graphics.Rectangle, painter: *Renderer, info: zero_graphics.UserInterface.CustomWidget.DrawInfo) Renderer.DrawError!void {
                    _ = self;
                    _ = info;
                    const Color = zero_graphics.Color;
                    try painter.fillRectangle(rectangle, if (mouse_in)
                        if (mouse_down)
                            Color{ .r = 0xFF, .g = 0x80, .b = 0x80, .a = 0x30 }
                        else
                            Color{ .r = 0xFF, .g = 0x80, .b = 0x80, .a = 0x10 }
                    else
                        Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = 0x10 });

                    startup_time = startup_time orelse zero_graphics.milliTimestamp();

                    var t = 0.001 * @intToFloat(f32, zero_graphics.milliTimestamp() - startup_time.?);
                    var points: [3][2]f32 = undefined;

                    for (points) |*pt, i| {
                        const offset = @intToFloat(f32, i);
                        const mirror = std.math.sin((1.0 + 0.2 * offset) * t + offset);

                        pt[0] = mirror * std.math.sin((0.1 * offset) * 0.4 * t + offset);
                        pt[1] = mirror * std.math.cos((0.1 * offset) * 0.4 * t + offset);
                    }

                    var real_pt: [3]zero_graphics.Point = undefined;
                    for (real_pt) |*dst, i| {
                        const src = points[i];
                        dst.* = .{
                            .x = rectangle.x + @floatToInt(i16, (0.5 + 0.5 * src[0]) * @intToFloat(f32, rectangle.width)),
                            .y = rectangle.y + @floatToInt(i16, (0.5 + 0.5 * src[1]) * @intToFloat(f32, rectangle.height)),
                        };
                    }
                    var prev = real_pt[real_pt.len - 1];
                    for (real_pt) |pt| {
                        try painter.drawLine(
                            pt.x,
                            pt.y,
                            prev.x,
                            prev.y,
                            zero_graphics.Color{ .r = 0xFF, .g = 0x00, .b = 0x80 },
                        );
                        prev = pt;
                    }
                }
            };
            _ = try ui.custom(.{ .x = 370, .y = 200, .width = 80, .height = 80 }, null, .{
                .draw = CustomWidget.draw,
                .process_event = CustomWidget.update,
            });
        }

        ui.finish();
    }

    return true;
}

pub fn render(app: *Application) !void {
    var take_screenshot = false;

    const renderer = &app.renderer;

    renderer.reset();

    // render scene
    {
        const Rectangle = zero_graphics.Rectangle;

        const red = zero_graphics.Color{ .r = 0xFF, .g = 0x00, .b = 0x00 };
        const white = zero_graphics.Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF };

        try renderer.fillRectangle(Rectangle{ .x = 1, .y = 1, .width = 16, .height = 16 }, .{ .r = 0xFF, .g = 0x00, .b = 0x00, .a = 0x80 });
        try renderer.fillRectangle(Rectangle{ .x = 9, .y = 9, .width = 16, .height = 16 }, .{ .r = 0x00, .g = 0xFF, .b = 0x00, .a = 0x80 });
        try renderer.fillRectangle(Rectangle{ .x = 17, .y = 17, .width = 16, .height = 16 }, .{ .r = 0x00, .g = 0x00, .b = 0xFF, .a = 0x80 });

        try renderer.fillRectangle(Rectangle{
            .x = app.screen_width - 64 - 1,
            .y = app.screen_height - 48 - 1,
            .width = 64,
            .height = 48,
        }, .{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = 0x80 });

        try renderer.drawRectangle(Rectangle{ .x = 1, .y = 34, .width = 32, .height = 32 }, white);

        // diagonal
        try renderer.fillRectangle(Rectangle{ .x = 34, .y = 34, .width = 32, .height = 32 }, red);
        try renderer.drawLine(34, 34, 65, 65, white);

        // vertical
        try renderer.fillRectangle(Rectangle{ .x = 1, .y = 67, .width = 32, .height = 32 }, red);
        try renderer.drawLine(1, 67, 1, 98, white);
        try renderer.drawLine(32, 67, 32, 98, white);

        // horizontal
        try renderer.fillRectangle(Rectangle{ .x = 34, .y = 67, .width = 32, .height = 32 }, red);
        try renderer.drawLine(34, 67, 65, 67, white);
        try renderer.drawLine(34, 98, 65, 98, white);

        try renderer.fillTexturedRectangle(
            Rectangle{
                .x = (app.screen_width - app.texture_handle.width) / 2,
                .y = (app.screen_height - app.texture_handle.height) / 2,
                .width = app.texture_handle.width,
                .height = app.texture_handle.height,
            },
            app.texture_handle,
            null,
        );

        const string = "Hello World, hello Ziguanas!";
        const string_size = renderer.measureString(app.font, string);

        try renderer.drawString(
            app.font,
            string,
            (app.screen_width - string_size.width) / 2,
            (app.screen_height + app.texture_handle.height) / 2,
            zero_graphics.Color{ .r = 0xF7, .g = 0xA4, .b = 0x1D },
        );

        // Paint the UI to the screen,
        // will paint to `renderer`
        try app.ui.render();

        const mouse = app.input.pointer_location;

        if (mouse.x >= 0 and mouse.y >= 0) {
            try renderer.drawLine(0, mouse.y, app.screen_width, mouse.y, .{ .r = 0xFF, .g = 0x00, .b = 0x00, .a = 0x40 });
            try renderer.drawLine(mouse.x, 0, mouse.x, app.screen_height, .{ .r = 0xFF, .g = 0x00, .b = 0x00, .a = 0x40 });
            try renderer.drawRectangle(
                Rectangle{
                    .x = mouse.x - 10,
                    .y = mouse.y - 10,
                    .width = 21,
                    .height = 21,
                },
                red,
            );
        }
    }

    app.renderer3d.reset();
    try app.renderer3d.drawGeometry(app.mesh, zlm.Mat4.identity.fields);

    // OpenGL rendering
    {
        const aspect = @intToFloat(f32, app.screen_width) / @intToFloat(f32, app.screen_height);

        gles.viewport(0, 0, app.screen_width, app.screen_height);

        gles.clearColor(0.3, 0.3, 0.3, 1.0);
        gles.clearDepthf(1.0);
        gles.clear(gles.COLOR_BUFFER_BIT | gles.DEPTH_BUFFER_BIT);

        gles.frontFace(gles.CCW);
        gles.cullFace(gles.BACK);

        const perspective_mat = zlm.SpecializeOn(f32).Mat4.createPerspective(
            zlm.toRadians(60.0),
            aspect,
            0.1,
            10_000.0,
        );

        const ts = @intToFloat(f32, zero_graphics.milliTimestamp() - app.startup_time) / 1000.0;

        const lookat_mat = zlm.SpecializeOn(f32).Mat4.createLookAt(
            // zlm.specializeOn(f32).vec3(0, 0, -10),
            zlm.SpecializeOn(f32).vec3(
                4.0 * std.math.sin(ts),
                3.0,
                4.0 * std.math.cos(ts),
            ),
            zlm.SpecializeOn(f32).Vec3.zero,
            zlm.SpecializeOn(f32).Vec3.unitY,
        );

        const view_projection_matrix = lookat_mat.mul(perspective_mat);

        app.renderer3d.render(view_projection_matrix.fields);

        renderer.render(zero_graphics.Size{ .width = app.screen_width, .height = app.screen_height });
    }

    if (builtin.os.tag != .freestanding) {
        if (take_screenshot) {
            take_screenshot = false;

            var buffer = try app.allocator.alloc(u8, 4 * @as(usize, app.screen_width) * @as(usize, app.screen_height));
            defer app.allocator.free(buffer);

            gles.pixelStorei(gles.PACK_ALIGNMENT, 1);
            gles.readPixels(0, 0, app.screen_width, app.screen_height, gles.RGBA, gles.UNSIGNED_BYTE, buffer.ptr);

            var file = try std.fs.cwd().createFile("screenshot.tga", .{});
            defer file.close();

            var buffered_writer = std.io.bufferedWriter(file.writer());

            var writer = buffered_writer.writer();

            const image_id = "Hello, TGA!";

            try writer.writeIntLittle(u8, @intCast(u8, image_id.len));
            try writer.writeIntLittle(u8, 0); // color map type = no color map
            try writer.writeIntLittle(u8, 2); // image type = uncompressed true-color image
            // color map spec
            try writer.writeIntLittle(u16, 0); // first index
            try writer.writeIntLittle(u16, 0); // length
            try writer.writeIntLittle(u8, 0); // number of bits per pixel
            // image spec
            try writer.writeIntLittle(u16, 0); // x origin
            try writer.writeIntLittle(u16, 0); // y origin
            try writer.writeIntLittle(u16, app.screen_width); // width
            try writer.writeIntLittle(u16, app.screen_height); // height
            try writer.writeIntLittle(u8, 32); // bits per pixel
            try writer.writeIntLittle(u8, 8); // 0…3 => alpha channel depth = 8, 4…7 => direction=bottom left

            try writer.writeAll(image_id);
            try writer.writeAll(""); // color map data \o/
            try writer.writeAll(buffer);

            try buffered_writer.flush();

            logger.info("screenshot written to screenshot.tga", .{});
        }
    }
}

const DemoGuiData = struct {
    is_visible: bool = false,

    last_button: ?usize = null,

    radio_group_1: usize = 0,
    radio_group_2: usize = 1,

    check_group: [4]bool = .{ false, false, false, false },
};
