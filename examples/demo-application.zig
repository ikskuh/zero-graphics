const std = @import("std");
const build_options = @import("build_options");
const zero_graphics = @import("zero-graphics");

const logger = std.log.scoped(.demo);
const gles = zero_graphics.gles;

/// This configures the application name that is shown in the android logging
pub const android_app_name = "zig-gles2-demo";

pub usingnamespace zero_graphics.EntryPoint(switch (build_options.render_backend) {
    .desktop_sdl2 => .desktop_sdl2,
    .wasm => .wasm,
    .android => .android,
});

const Renderer = zero_graphics.Renderer2D;

/// export this application struct to provide
/// zero-graphics with a main entry point.
/// Must export the following functions:
/// - `pub fn init(app: *Application, allocator: *std.mem.Allocator) !void`
/// - `pub fn deinit(app: *Application) void`
/// - `pub fn resize(app: *Application, width: u15, height: u15) !void`
/// - `pub fn update(app: *Application) !bool`
/// 
pub const Application = struct {
    screen_width: u15,
    screen_height: u15,
    renderer: Renderer,
    texture_handle: *const Renderer.Texture,
    allocator: *std.mem.Allocator,
    font: *const Renderer.Font,
    input: *zero_graphics.Input,

    ui: zero_graphics.UserInterface,

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
        };

        try gles.load({}, loadOpenGlFunction);

        const RequestedExtensions = struct {
            KHR_debug: bool,
        };

        const available_extensions = blk: {
            var exts = std.mem.zeroes(RequestedExtensions);

            if (std.builtin.cpu.arch != .wasm32) {
                const extension_list = std.mem.span(gles.getString(gles.EXTENSIONS)) orelse break :blk exts;
                var iterator = std.mem.split(extension_list, " ");
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

        // If possible, install the debug callback in debug builds
        if (std.builtin.mode == .Debug and available_extensions.KHR_debug) {
            const debug = gles.GL_KHR_debug;
            try debug.load({}, loadOpenGlFunction);

            debug.debugMessageCallbackKHR(glesDebugProc, null);
            gles.enable(debug.DEBUG_OUTPUT_KHR);
        }

        app.renderer = try Renderer.init(app.allocator);
        errdefer app.renderer.deinit();

        // app.texture_handle = try app.renderer.createTexture(128, 128, @embedFile("cat.rgba"));
        app.texture_handle = try app.renderer.loadTexture(@embedFile("ziggy.png"));
        app.font = try app.renderer.createFont(@embedFile("GreatVibes-Regular.ttf"), 48);

        const ui_font = try app.renderer.createFont(@embedFile("FiraSans-Regular.ttf"), 16);

        app.ui = zero_graphics.UserInterface.init(app.allocator, ui_font);
        errdefer app.ui.deinit();
    }

    pub fn deinit(app: *Application) void {
        app.ui.deinit();
        app.renderer.deinit();
        app.* = undefined;
    }

    pub fn resize(app: *Application, width: u15, height: u15) !void {
        if (width != app.screen_width or height != app.screen_height) {
            logger.info("screen resized to resolution: {}×{}", .{ width, height });
            app.screen_width = @intCast(u15, width);
            app.screen_height = @intCast(u15, height);
        }
    }

    pub fn update(app: *Application) !bool {
        var take_screenshot = false;

        {
            var ui_input = app.ui.processInput();
            while (app.input.pollEvent()) |event| {
                switch (event) {
                    .quit => return false,
                    .pointer_motion => |pt| ui_input.setPointer(pt),
                    .pointer_press => |cursor| if (cursor == .primary) ui_input.pointerDown(),
                    .pointer_release => |cursor| if (cursor == .primary) ui_input.pointerUp(),
                    .text_input => |text| try ui_input.enterText(text.text),
                }
            }
            ui_input.finish();
        }

        {
            var ui = app.ui.construct();

            var i: u15 = 0;
            while (i < 3) : (i += 1) {
                const rect = zero_graphics.Rectangle{
                    .x = 200 + 50 * i,
                    .y = 50 + 20 * i,
                    .width = 100,
                    .height = 40,
                };
                const clicked = try ui.button(rect, "Click me!", .{ .id = i });
                if (clicked) {
                    logger.info("Button {} was clicked!", .{i});
                }
            }

            ui.finish();
        }

        const renderer = &app.renderer;

        // render scene
        {
            const red = Renderer.Color{ .r = 0xFF, .g = 0x00, .b = 0x00 };
            const white = Renderer.Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF };

            renderer.reset();

            try renderer.fillRectangle(1, 1, 16, 16, .{ .r = 0xFF, .g = 0x00, .b = 0x00, .a = 0x80 });
            try renderer.fillRectangle(9, 9, 16, 16, .{ .r = 0x00, .g = 0xFF, .b = 0x00, .a = 0x80 });
            try renderer.fillRectangle(17, 17, 16, 16, .{ .r = 0x00, .g = 0x00, .b = 0xFF, .a = 0x80 });

            try renderer.fillRectangle(app.screen_width - 64 - 1, app.screen_height - 48 - 1, 64, 48, .{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = 0x80 });

            try renderer.drawRectangle(1, 34, 32, 32, white);

            // diagonal
            try renderer.fillRectangle(34, 34, 32, 32, red);
            try renderer.drawLine(34, 34, 65, 65, white);

            // vertical
            try renderer.fillRectangle(1, 67, 32, 32, red);
            try renderer.drawLine(1, 67, 1, 98, white);
            try renderer.drawLine(32, 67, 32, 98, white);

            // horizontal
            try renderer.fillRectangle(34, 67, 32, 32, red);
            try renderer.drawLine(34, 67, 65, 67, white);
            try renderer.drawLine(34, 98, 65, 98, white);

            try renderer.fillTexturedRectangle(
                (app.screen_width - app.texture_handle.width) / 2,
                (app.screen_height - app.texture_handle.height) / 2,
                app.texture_handle.width,
                app.texture_handle.height,
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
                Renderer.Color{ .r = 0xF7, .g = 0xA4, .b = 0x1D },
            );

            // Paint the UI to the screen
            try app.ui.render(renderer);

            const mouse = app.input.pointer_location;

            if (mouse.x >= 0 and mouse.y >= 0) {
                try renderer.drawRectangle(
                    mouse.x - 10,
                    mouse.y - 10,
                    21,
                    21,
                    red,
                );
            }
        }

        // OpenGL rendering
        {
            gles.viewport(0, 0, app.screen_width, app.screen_height);

            gles.clearColor(0.3, 0.3, 0.3, 1.0);
            gles.clear(gles.COLOR_BUFFER_BIT);

            gles.frontFace(gles.CCW);
            gles.cullFace(gles.BACK);

            renderer.render(app.screen_width, app.screen_height);
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

        return true;
    }
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
