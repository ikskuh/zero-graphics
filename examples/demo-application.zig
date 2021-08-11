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
const zlm = @import("zlm");
const zero_graphics = @import("zero-graphics");

const logger = std.log.scoped(.demo);
const gles = zero_graphics.gles;

const Renderer = zero_graphics.Renderer2D;
const Renderer3D = zero_graphics.Renderer3D;

const Application = @This();

screen_width: u15,
screen_height: u15,
renderer: Renderer,
texture_handle: *const Renderer.Texture,
allocator: *std.mem.Allocator,
font: *const Renderer.Font,
input: *zero_graphics.Input,

ui: zero_graphics.UserInterface,

gui_data: DemoGuiData = .{},

renderer3d: Renderer3D,
mesh: *const Renderer3D.Geometry,

startup_time: i64,

pub fn init(app: *Application, allocator: *std.mem.Allocator, input: *zero_graphics.Input) !void {
    app.* = Application{
        .allocator = allocator,
        .screen_width = 0,
        .screen_height = 0,
        .texture_handle = undefined,
        .renderer = undefined,
        .ui = undefined,
        .font = undefined,
        .input = input,

        .renderer3d = undefined,
        .mesh = undefined,

        .startup_time = zero_graphics.milliTimestamp(),
    };

    app.ui = try zero_graphics.UserInterface.init(app.allocator, null);
    errdefer app.ui.deinit();
}

pub fn deinit(app: *Application) void {
    app.ui.deinit();
    app.* = undefined;
}

pub fn setupGraphics(app: *Application) !void {
    // Load required extensions here:
    const RequestedExtensions = struct {
        KHR_debug: bool,
    };

    const available_extensions = blk: {
        var exts = std.mem.zeroes(RequestedExtensions);

        if (std.builtin.cpu.arch != .wasm32) {
            const extension_list = std.mem.span(gles.getString(gles.EXTENSIONS)) orelse break :blk exts;
            var iterator = std.mem.split(u8, extension_list, " ");
            while (iterator.next()) |extension| {
                inline for (std.meta.fields(RequestedExtensions)) |fld| {
                    if (std.mem.eql(u8, extension, "GL_" ++ fld.name)) {
                        @field(exts, fld.name) = true;
                    }
                }
            }
        }

        break :blk exts;
    };

    {
        logger.info("OpenGL Version:       {s}", .{std.mem.span(gles.getString(gles.VERSION))});
        logger.info("OpenGL Vendor:        {s}", .{std.mem.span(gles.getString(gles.VENDOR))});
        logger.info("OpenGL Renderer:      {s}", .{std.mem.span(gles.getString(gles.RENDERER))});
        logger.info("OpenGL GLSL:          {s}", .{std.mem.span(gles.getString(gles.SHADING_LANGUAGE_VERSION))});

        logger.info("Available extensions: {}", .{available_extensions});
    }

    logger.info("Display density: {d:.3} DPI", .{zero_graphics.getDisplayDPI()});

    // If possible, install the debug callback in debug builds
    if (std.builtin.mode == .Debug and available_extensions.KHR_debug) {
        const debug = gles.GL_KHR_debug;
        try debug.load({}, zero_graphics.loadOpenGlFunction);

        debug.debugMessageCallbackKHR(glesDebugProc, null);
        gles.enable(debug.DEBUG_OUTPUT_KHR);
    }

    app.renderer = try Renderer.init(app.allocator);
    errdefer app.renderer.deinit();

    // app.texture_handle = try app.renderer.createTexture(128, 128, @embedFile("cat.rgba"));
    app.texture_handle = try app.renderer.loadTexture(@embedFile("ziggy.png"));
    app.font = try app.renderer.createFont(@embedFile("GreatVibes-Regular.ttf"), 48);

    try app.ui.setRenderer(&app.renderer);

    app.renderer3d = try Renderer3D.init(app.allocator);
    errdefer app.renderer3d.deinit();

    app.mesh = try app.renderer3d.loadGeometry(
        @embedFile("twocubes.z3d"),
        {},
        struct {
            fn f(ren: *Renderer3D, ctx: void, file_name: []const u8) !*const Renderer3D.Texture {
                _ = ctx;
                if (std.mem.eql(u8, file_name, "metal-01.png"))
                    return try ren.loadTexture(@embedFile("data/metal-01.png"));
                if (std.mem.eql(u8, file_name, "metal-02.png"))
                    return try ren.loadTexture(@embedFile("data/metal-02.png"));
                return error.FileNotFound;
            }
        }.f,
    );
}

pub fn teardownGraphics(app: *Application) void {
    app.ui.setRenderer(null) catch unreachable;
    app.renderer.deinit();

    app.renderer3d.destroyGeometry(app.mesh);
    app.renderer3d.deinit();
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
                .text_input => |text| try ui_input.enterText(text.text),
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

        const perspective_mat = zlm.specializeOn(f32).Mat4.createPerspective(
            zlm.toRadians(60.0),
            aspect,
            0.1,
            10_000.0,
        );

        const ts = @intToFloat(f32, zero_graphics.milliTimestamp() - app.startup_time) / 1000.0;

        const lookat_mat = zlm.specializeOn(f32).Mat4.createLookAt(
            // zlm.specializeOn(f32).vec3(0, 0, -10),
            zlm.specializeOn(f32).vec3(
                4.0 * std.math.sin(ts),
                3.0,
                4.0 * std.math.cos(ts),
            ),
            zlm.specializeOn(f32).Vec3.zero,
            zlm.specializeOn(f32).Vec3.unitY,
        );

        const view_projection_matrix = lookat_mat.mul(perspective_mat);

        app.renderer3d.render(view_projection_matrix.fields);

        renderer.render(zero_graphics.Size{ .width = app.screen_width, .height = app.screen_height });
    }

    if (std.builtin.os.tag != .freestanding) {
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

fn glesDebugProc(
    source: gles.GLenum,
    msg_type: gles.GLenum,
    id: gles.GLuint,
    severity: gles.GLenum,
    length: gles.GLsizei,
    message_ptr: [*:0]const u8,
    userParam: ?*c_void,
) callconv(.C) void {
    _ = msg_type;
    _ = userParam;
    _ = id;
    // This callback is only used when the extension is available
    const debug = gles.GL_KHR_debug;

    const source_name = switch (source) {
        debug.DEBUG_SOURCE_API_KHR => "api",
        debug.DEBUG_SOURCE_WINDOW_SYSTEM_KHR => "window system",
        debug.DEBUG_SOURCE_SHADER_COMPILER_KHR => "shader compiler",
        debug.DEBUG_SOURCE_THIRD_PARTY_KHR => "third party",
        debug.DEBUG_SOURCE_APPLICATION_KHR => "application",
        debug.DEBUG_SOURCE_OTHER_KHR => "other",
        else => "unknown",
    };

    const type_name = switch (msg_type) {
        debug.DEBUG_TYPE_ERROR_KHR => "error",
        debug.DEBUG_TYPE_DEPRECATED_BEHAVIOR_KHR => "deprecated behavior",
        debug.DEBUG_TYPE_UNDEFINED_BEHAVIOR_KHR => "undefined behavior",
        debug.DEBUG_TYPE_PORTABILITY_KHR => "portability",
        debug.DEBUG_TYPE_PERFORMANCE_KHR => "performance",
        debug.DEBUG_TYPE_OTHER_KHR => "other",
        debug.DEBUG_TYPE_MARKER_KHR => "marker",
        debug.DEBUG_TYPE_PUSH_GROUP_KHR => "push group",
        debug.DEBUG_TYPE_POP_GROUP_KHR => "pop group",
        else => "unknown",
    };
    const message = message_ptr[0..@intCast(usize, length)];

    const fmt_string = "[{s}] [{s}] {s}";
    var fmt_arg = .{ source_name, type_name, message };

    switch (severity) {
        debug.DEBUG_SEVERITY_HIGH_KHR => logger.emerg(fmt_string, fmt_arg),
        debug.DEBUG_SEVERITY_MEDIUM_KHR => logger.err(fmt_string, fmt_arg),
        debug.DEBUG_SEVERITY_LOW_KHR => logger.warn(fmt_string, fmt_arg),
        debug.DEBUG_SEVERITY_NOTIFICATION_KHR => logger.info(fmt_string, fmt_arg),
        else => logger.emerg("encountered invalid log severity: {}", .{severity}),
    }
}
