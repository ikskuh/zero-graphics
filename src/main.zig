const std = @import("std");
const c = @cImport({
    @cInclude("SDL.h");
});
const gles = @import("gl_es_2v0.zig");
const log = std.log.scoped(.demo);

const RequestedExtensions = struct {
    KHR_debug: bool,
};

pub fn main() anyerror!void {
    _ = c.SDL_Init(c.SDL_INIT_EVERYTHING);
    defer _ = c.SDL_Quit();

    _ = c.SDL_GL_SetAttribute(.SDL_GL_CONTEXT_MAJOR_VERSION, 2);
    _ = c.SDL_GL_SetAttribute(.SDL_GL_CONTEXT_MINOR_VERSION, 0);

    _ = c.SDL_GL_SetAttribute(.SDL_GL_DOUBLEBUFFER, 1);
    //    _ = c.SDL_GL_SetAttribute(.SDL_GL_DEPTH_SIZE, 24);
    _ = c.SDL_GL_SetAttribute(.SDL_GL_CONTEXT_PROFILE_MASK, c.SDL_GL_CONTEXT_PROFILE_ES);

    if (std.builtin.mode == .Debug) {
        _ = c.SDL_GL_SetAttribute(.SDL_GL_CONTEXT_FLAGS, c.SDL_GL_CONTEXT_DEBUG_FLAG);
    }

    const window = c.SDL_CreateWindow(
        "OpenGL ES 2.0 - Zig Demo",
        c.SDL_WINDOWPOS_CENTERED,
        c.SDL_WINDOWPOS_CENTERED,
        640,
        480,
        c.SDL_WINDOW_OPENGL | c.SDL_WINDOW_SHOWN | c.SDL_WINDOW_ALLOW_HIGHDPI | c.SDL_WINDOW_MAXIMIZED | c.SDL_WINDOW_FULLSCREEN_DESKTOP,
    ) orelse sdlPanic();
    defer c.SDL_DestroyWindow(window);

    const gl_context = c.SDL_GL_CreateContext(window) orelse sdlPanic();
    defer c.SDL_GL_DeleteContext(gl_context);

    try gles.load({}, sdlLoadOpenGlFunction);

    const available_extensions = blk: {
        var exts = std.mem.zeroes(RequestedExtensions);

        const extension_list = std.mem.span(gles.getString(gles.EXTENSIONS)) orelse break :blk exts;
        var iterator = std.mem.split(extension_list, " ");
        while (iterator.next()) |extension| {
            inline for (std.meta.fields(RequestedExtensions)) |fld| {
                if (std.mem.eql(u8, extension, "GL_" ++ fld.name)) {
                    @field(exts, fld.name) = true;
                }
            }
        }

        break :blk exts;
    };

    {
        log.info("SDL Video Driver:     {s}", .{std.mem.span(c.SDL_GetCurrentVideoDriver())});
        log.info("OpenGL Version:       {s}", .{std.mem.span(gles.getString(gles.VERSION))});
        log.info("OpenGL Vendor:        {s}", .{std.mem.span(gles.getString(gles.VENDOR))});
        log.info("OpenGL Renderer:      {s}", .{std.mem.span(gles.getString(gles.RENDERER))});
        log.info("OpenGL GLSL:          {s}", .{std.mem.span(gles.getString(gles.SHADING_LANGUAGE_VERSION))});

        log.info("Available extensions: {}", .{available_extensions});

        var width: c_int = undefined;
        var height: c_int = undefined;
        c.SDL_GL_GetDrawableSize(window, &width, &height);
        log.info("Render resolution:  {}×{}", .{ width, height });

        c.SDL_GetWindowSize(window, &width, &height);
        log.info("Virtual resolution: {}×{}", .{ width, height });
    }

    // If possible, install the debug callback in debug builds
    if (std.builtin.mode == .Debug and available_extensions.KHR_debug) {
        const debug = gles.GL_KHR_debug;
        try debug.load({}, sdlLoadOpenGlFunction);

        debug.debugMessageCallbackKHR(glesDebugProc, null);
        gles.enable(debug.DEBUG_OUTPUT_KHR);
    }

    var renderer = try Renderer.init(std.heap.c_allocator);
    defer renderer.deinit();

    var first_frame = true;

    var screen_width: u15 = 0;
    var screen_height: u15 = 0;

    main_loop: while (true) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                c.SDL_QUIT => break :main_loop,
                c.SDL_WINDOWEVENT => {
                    log.info("unhandled window event: {}", .{@intToEnum(c.SDL_WindowEventID, event.window.event)});
                },
                else => log.info("unhandled event: {}", .{@intToEnum(c.SDL_EventType, @intCast(c_int, event.type))}),
            }
        }

        {
            var width: c_int = undefined;
            var height: c_int = undefined;

            c.SDL_GL_GetDrawableSize(window, &width, &height);

            if (width != screen_width or height != screen_height) {
                log.info("screen resized to resolution: {}×{}", .{ width, height });

                screen_width = @intCast(u15, width);
                screen_height = @intCast(u15, height);

                first_frame = true;
            }
        }

        gles.viewport(0, 0, screen_width, screen_height);

        // render scene
        {
            const red = Color{ .r = 0xFF, .g = 0x00, .b = 0x00 };
            const white = Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF };

            renderer.reset();

            try renderer.fillRectangle(1, 1, 16, 16, .{ .r = 0xFF, .g = 0x00, .b = 0x00, .a = 0x80 });
            try renderer.fillRectangle(9, 9, 16, 16, .{ .r = 0x00, .g = 0xFF, .b = 0x00, .a = 0x80 });
            try renderer.fillRectangle(17, 17, 16, 16, .{ .r = 0x00, .g = 0x00, .b = 0xFF, .a = 0x80 });

            try renderer.fillRectangle(screen_width - 64 - 1, screen_height - 48 - 1, 64, 48, .{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = 0x80 });

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
        }

        {
            gles.clearColor(0.3, 0.3, 0.3, 1.0);
            gles.clear(gles.COLOR_BUFFER_BIT);

            gles.frontFace(gles.CCW);
            gles.cullFace(gles.BACK);

            if (c.SDL_GetKeyboardState(null)[c.SDL_SCANCODE_SPACE] != 0) {
                gles.disable(gles.CULL_FACE);
            } else {
                gles.enable(gles.CULL_FACE);
            }

            renderer.render(screen_width, screen_height);
        }

        if (first_frame) {
            first_frame = false;

            var buffer = try std.heap.c_allocator.alloc(u8, 4 * @as(usize, screen_width) * @as(usize, screen_height));
            defer std.heap.c_allocator.free(buffer);

            gles.pixelStorei(gles.PACK_ALIGNMENT, 1);
            gles.readPixels(0, 0, screen_width, screen_height, gles.RGBA, gles.UNSIGNED_BYTE, buffer.ptr);

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
            try writer.writeIntLittle(u16, screen_width); // width
            try writer.writeIntLittle(u16, screen_height); // height
            try writer.writeIntLittle(u8, 32); // bits per pixel
            try writer.writeIntLittle(u8, 8); // 0…3 => alpha channel depth = 8, 4…7 => direction=bottom left

            try writer.writeAll(image_id);
            try writer.writeAll(""); // color map data \o/
            try writer.writeAll(buffer);

            try buffered_writer.flush();
        }

        c.SDL_GL_SwapWindow(window);
    }
}

const Renderer = struct {
    const Self = @This();

    const Vertex = extern struct {
        // coordinates on the screen in pixels:
        x: f32,
        y: f32,
        // color of the vertex:
        r: u8,
        g: u8,
        b: u8,
        a: u8,

        /// Makes a new vertex at the given integer coordinates
        fn init(x: i16, y: i16, color: Color) @This() {
            return .{
                .x = @intToFloat(f32, x),
                .y = @intToFloat(f32, y),
                .r = color.r,
                .g = color.g,
                .b = color.b,
                .a = color.a,
            };
        }

        /// offsets the vertex by (`dx`,`dy`) half pixels
        fn offset(self: @This(), dx: f32, dy: f32) @This() {
            var v = self;
            v.x += 0.5 * dx;
            v.y += 0.5 * dy;
            return v;
        }
    };

    const vertexSource =
        \\attribute vec2 vPosition;
        \\attribute vec4 vColor;
        \\uniform ivec2 uScreenSize;
        \\varying vec4 fColor;
        \\void main()
        \\{
        \\   vec2 virtual_position = (vPosition + 0.375) / vec2(uScreenSize);
        \\   gl_Position = vec4(2.0 * virtual_position.x - 1.0, 1.0 - 2.0 * virtual_position.y, 0.0, 1.0);
        \\   fColor = vColor;
        \\}
    ;
    const fragmentSource =
        \\precision mediump float;
        \\varying vec4 fColor;
        \\void main()
        \\{
        \\  gl_FragColor = fColor;
        \\}
    ;

    shader_program: gles.GLuint,
    screen_size_location: gles.GLint,

    vertex_buffer: gles.GLuint,

    position_attribute_location: gles.GLuint,
    color_attribute_location: gles.GLuint,

    /// list of CCW triangles that will be rendered 
    vertices: std.ArrayList(Vertex),

    pub fn init(allocator: *std.mem.Allocator) !Self {
        const shader_program = blk: {
            // Create and compile vertex shader
            const vertex_shader = try createAndCompileShader(gles.VERTEX_SHADER, vertexSource);
            defer gles.deleteShader(vertex_shader);

            const fragment_shader = try createAndCompileShader(gles.FRAGMENT_SHADER, fragmentSource);
            defer gles.deleteShader(fragment_shader);

            const program = gles.createProgram();

            gles.attachShader(program, vertex_shader);
            defer gles.detachShader(program, vertex_shader);

            gles.attachShader(program, fragment_shader);
            defer gles.detachShader(program, fragment_shader);

            gles.linkProgram(program);

            var status: gles.GLint = undefined;
            gles.getProgramiv(program, gles.LINK_STATUS, &status);
            if (status != gles.TRUE)
                return error.FailedToLinkProgram;

            break :blk program;
        };
        errdefer gles.deleteProgram(shader_program);

        // Create vertex buffer object and copy vertex data into it
        var vertex_buffer: gles.GLuint = 0;
        gles.genBuffers(1, &vertex_buffer);
        errdefer gles.deleteBuffers(1, &vertex_buffer);

        const position_attribute_location = std.math.cast(gles.GLuint, gles.getAttribLocation(shader_program, "vPosition")) catch return error.MissingShaderAttribute;
        const color_attribute_location = std.math.cast(gles.GLuint, gles.getAttribLocation(shader_program, "vColor")) catch return error.MissingShaderAttribute;

        gles.enableVertexAttribArray(position_attribute_location);
        gles.enableVertexAttribArray(color_attribute_location);

        gles.bindBuffer(gles.ARRAY_BUFFER, vertex_buffer);
        gles.vertexAttribPointer(position_attribute_location, 2, gles.FLOAT, gles.FALSE, @sizeOf(Vertex), @intToPtr(?*const c_void, @byteOffsetOf(Vertex, "x")));
        gles.vertexAttribPointer(color_attribute_location, 4, gles.UNSIGNED_BYTE, gles.TRUE, @sizeOf(Vertex), @intToPtr(?*const c_void, @byteOffsetOf(Vertex, "r")));

        return Self{
            .shader_program = shader_program,
            .screen_size_location = gles.getUniformLocation(shader_program, "uScreenSize"),
            .vertices = std.ArrayList(Vertex).init(allocator),
            .vertex_buffer = vertex_buffer,
            .position_attribute_location = position_attribute_location,
            .color_attribute_location = color_attribute_location,
        };
    }

    pub fn deinit(self: *Self) void {
        gles.deleteBuffers(1, &self.vertex_buffer);
        gles.deleteProgram(self.shader_program);
        self.vertices.deinit();
        self.* = undefined;
    }

    /// Resets the state of the renderer and prepares a fresh new frame.
    pub fn reset(self: *Self) void {
        self.vertices.shrinkRetainingCapacity(0);
    }

    /// Renders the currently contained data to the screen.
    pub fn render(self: Self, width: u15, height: u15) void {
        gles.bindBuffer(gles.ARRAY_BUFFER, self.vertex_buffer);
        gles.bufferData(gles.ARRAY_BUFFER, @intCast(gles.GLsizeiptr, @sizeOf(Vertex) * self.vertices.items.len), self.vertices.items.ptr, gles.STATIC_DRAW);

        gles.useProgram(self.shader_program);
        gles.uniform2i(self.screen_size_location, width, height);

        gles.enable(gles.BLEND);
        gles.blendFunc(gles.SRC_ALPHA, gles.ONE_MINUS_SRC_ALPHA);
        gles.blendEquation(gles.FUNC_ADD);

        gles.drawArrays(gles.TRIANGLES, 0, @intCast(gles.GLsizei, self.vertices.items.len));
    }

    /// Appends a filled, untextured quad.
    pub fn fillRectangle(self: *Self, x: i16, y: i16, width: u15, height: u15, color: Color) !void {
        const tl = Vertex.init(x, y, color);
        const tr = Vertex.init(x + width, y, color);
        const bl = Vertex.init(x, y + height, color);
        const br = Vertex.init(x + width, y + height, color);

        try self.vertices.appendSlice(&[_]Vertex{
            tl, br, tr,
            br, tl, bl,
        });
    }

    /// Appends a rectangle with a 1 pixel wide outline
    pub fn drawRectangle(self: *Self, x: i16, y: i16, width: u15, height: u15, color: Color) !void {
        const tl = Vertex.init(x, y, color);
        const tr = Vertex.init(x + width - 1, y, color);
        const bl = Vertex.init(x, y + height - 1, color);
        const br = Vertex.init(x + width - 1, y + height - 1, color);

        try self.vertices.appendSlice(&[_]Vertex{
            // top
            tl.offset(-1, -1), tr.offset(-1, 1),  tr.offset(1, -1),
            tr.offset(-1, 1),  tl.offset(-1, -1), tl.offset(1, 1),
            // right
            tr.offset(1, -1),  tr.offset(-1, 1),  br.offset(-1, -1),
            br.offset(-1, -1), br.offset(1, 1),   tr.offset(1, -1),
            // bottom
            br.offset(-1, -1), bl.offset(-1, 1),  br.offset(1, 1),
            br.offset(-1, -1), bl.offset(1, -1),  bl.offset(-1, 1),
            // left
            bl.offset(1, -1),  tl.offset(-1, -1), bl.offset(-1, 1),
            bl.offset(1, 1),   tl.offset(1, 1),   tl.offset(-1, -1),
        });
    }

    /// Draws a single pixel wide line from (`x0`,`y0`) to (`x1`,`y1`)
    pub fn drawLine(self: *Self, x0: i16, y0: i16, x1: i16, y1: i16, color: Color) !void {
        const p0 = Vertex.init(x0, y0, color);
        const p1 = Vertex.init(x1, y1, color);

        const dx = p1.x - p0.x;
        const dy = p1.y - p0.y;

        const len = std.math.sqrt(dx * dx + dy * dy);

        const ox_x = dx / len;
        const ox_y = dy / len;

        const oy_x = ox_y;
        const oy_y = -ox_x;

        try self.vertices.appendSlice(&[_]Vertex{
            p0.offset(-ox_x, -ox_y).offset(-oy_x, -oy_y),
            p1.offset(ox_x, ox_y).offset(-oy_x, -oy_y),
            p1.offset(ox_x, ox_y).offset(oy_x, oy_y),

            p0.offset(-ox_x, -ox_y).offset(-oy_x, -oy_y),
            p1.offset(ox_x, ox_y).offset(oy_x, oy_y),
            p0.offset(-ox_x, -ox_y).offset(oy_x, oy_y),
        });
    }

    fn createAndCompileShader(shader_type: gles.GLenum, source: []const u8) !gles.GLuint {
        const source_ptr = source.ptr;
        const source_len = @intCast(gles.GLint, source.len);

        // Create and compile vertex shader
        const shader = gles.createShader(shader_type);
        errdefer gles.deleteShader(shader);

        gles.shaderSource(
            shader,
            1,
            @ptrCast([*]const [*c]const u8, &source_ptr),
            @ptrCast([*]const gles.GLint, &source_len),
        );
        gles.compileShader(shader);

        var status: gles.GLint = undefined;
        gles.getShaderiv(shader, gles.COMPILE_STATUS, &status);
        if (status != gles.TRUE)
            return error.FailedToCompileShader;

        return shader;
    }
};

const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 0xFF,
};

fn sdlPanic() noreturn {
    @panic(std.mem.span(c.SDL_GetError()));
}

fn sdlLoadOpenGlFunction(ctx: void, function: [:0]const u8) ?*c_void {
    return c.SDL_GL_GetProcAddress(function.ptr);
}

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
        debug.DEBUG_SEVERITY_HIGH_KHR => log.emerg(fmt_string, fmt_arg),
        debug.DEBUG_SEVERITY_MEDIUM_KHR => log.err(fmt_string, fmt_arg),
        debug.DEBUG_SEVERITY_LOW_KHR => log.warn(fmt_string, fmt_arg),
        debug.DEBUG_SEVERITY_NOTIFICATION_KHR => log.info(fmt_string, fmt_arg),
        else => log.emerg("encountered invalid log severity: {}", .{severity}),
    }
}
