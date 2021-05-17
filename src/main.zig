const std = @import("std");
const build_options = @import("build_options");

const logger = std.log.scoped(.demo);
// opengl docs can be found here:
// https://www.khronos.org/registry/OpenGL-Refpages/es2.0/
const gles = @import("gl_es_2v0.zig");

const backend = switch (build_options.render_backend) {
    .desktop_sdl2 => @import("sdl.zig"),
    .wasm => @import("wasm.zig"),
};

pub usingnamespace backend;

comptime {
    _ = backend;
    _ = backend.loadOpenGlFunction;
}

pub const Application = struct {
    screen_width: u15,
    screen_height: u15,
    renderer: Renderer,
    texture_handle: *const Renderer.Texture,
    allocator: *std.mem.Allocator,

    pub fn init(app: *Application, allocator: *std.mem.Allocator) !void {
        app.* = Application{
            .allocator = allocator,
            .screen_width = 0,
            .screen_height = 0,
            .texture_handle = undefined,
            .renderer = undefined,
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

        //{
        //    logger.info("OpenGL Version:       {s}", .{std.mem.span(gles.getString(gles.VERSION))});
        //    logger.info("OpenGL Vendor:        {s}", .{std.mem.span(gles.getString(gles.VENDOR))});
        //    logger.info("OpenGL Renderer:      {s}", .{std.mem.span(gles.getString(gles.RENDERER))});
        //    logger.info("OpenGL GLSL:          {s}", .{std.mem.span(gles.getString(gles.SHADING_LANGUAGE_VERSION))});

        //    logger.info("Available extensions: {}", .{available_extensions});
        //}

        // If possible, install the debug callback in debug builds
        if (std.builtin.mode == .Debug and available_extensions.KHR_debug) {
            const debug = gles.GL_KHR_debug;
            try debug.load({}, loadOpenGlFunction);

            debug.debugMessageCallbackKHR(glesDebugProc, null);
            gles.enable(debug.DEBUG_OUTPUT_KHR);
        }

        app.renderer = try Renderer.init(app.allocator);
        errdefer app.renderer.deinit();

        app.texture_handle = try app.renderer.createTexture(128, 128, @embedFile("cat.rgba"));
    }

    pub fn deinit(app: *Application) void {
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

        const renderer = &app.renderer;

        // render scene
        {
            const red = Color{ .r = 0xFF, .g = 0x00, .b = 0x00 };
            const white = Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF };

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
        }

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

const Renderer = struct {
    const Self = @This();

    pub const Vertex = extern struct {
        // coordinates on the screen in pixels:
        x: f32,
        y: f32,
        u: f32,
        v: f32,
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
                .u = 0,
                .v = 0,
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

        /// changes the UV coordinates of the vertex.
        fn withUV(self: @This(), u: f32, v: f32) @This() {
            var vert = self;
            vert.u = u;
            vert.v = v;
            return vert;
        }
    };

    pub const Texture = struct {
        /// private texture handle
        handle: gles.GLuint,

        /// private reference counter.
        /// This is required as texture references are held in the internal draw 
        /// queue when passing them into a draw command and will be released after
        /// the `render()` call
        refcount: usize,

        /// width of the texture in pixels
        width: u15,

        /// height of the texture in pixels
        height: u15,
    };

    const DrawCall = struct {
        offset: usize,
        count: usize,
        texture: ?*const Texture,
    };

    const TextureList = std.TailQueue(Texture);
    const TextureItem = std.TailQueue(Texture).Node;

    const CollectError = error{OutOfMemory};
    const CreateTextureError = error{ OutOfMemory, GraphicsApiFailure };
    const InitError = error{ OutOfMemory, GraphicsApiFailure };

    const vertexSource =
        \\attribute vec2 vPosition;
        \\attribute vec4 vColor;
        \\attribute vec2 vUV;
        \\uniform ivec2 uScreenSize;
        \\varying vec4 fColor;
        \\varying vec2 fUV;
        \\void main()
        \\{
        \\   vec2 virtual_position = (vPosition + 0.5) / vec2(uScreenSize);
        \\   gl_Position = vec4(2.0 * virtual_position.x - 1.0, 1.0 - 2.0 * virtual_position.y, 0.0, 1.0);
        \\   fColor = vColor;
        \\   fUV = vUV;
        \\}
    ;
    const fragmentSource =
        \\precision mediump float;
        \\varying vec4 fColor;
        \\varying vec2 fUV;
        \\uniform float uTextureEnable;
        \\uniform sampler2D uTexture;
        \\void main()
        \\{
        \\   vec4 base_color = mix(vec4(1), texture2D(uTexture, fUV), uTextureEnable);
        \\   gl_FragColor = fColor * base_color;
        \\}
    ;

    shader_program: gles.GLuint,
    screen_size_location: gles.GLint,
    texture_enable_location: gles.GLint,
    texture_location: gles.GLint,

    vertex_buffer: gles.GLuint,

    position_attribute_location: gles.GLuint,
    color_attribute_location: gles.GLuint,
    uv_attribute_location: gles.GLuint,

    /// list of CCW triangles that will be rendered 
    vertices: std.ArrayList(Vertex),
    draw_calls: std.ArrayList(DrawCall),

    allocator: *std.mem.Allocator,
    textures: TextureList,

    pub fn init(allocator: *std.mem.Allocator) InitError!Self {
        const shader_program = blk: {
            // Create and compile vertex shader
            const vertex_shader = createAndCompileShader(gles.VERTEX_SHADER, vertexSource) catch return error.GraphicsApiFailure;
            defer gles.deleteShader(vertex_shader);

            const fragment_shader = createAndCompileShader(gles.FRAGMENT_SHADER, fragmentSource) catch return error.GraphicsApiFailure;
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
                return error.GraphicsApiFailure;

            break :blk program;
        };
        errdefer gles.deleteProgram(shader_program);

        // Create vertex buffer object and copy vertex data into it
        var vertex_buffer: gles.GLuint = 0;
        gles.genBuffers(1, &vertex_buffer);
        if (vertex_buffer == 0)
            return error.GraphicsApiFailure;
        errdefer gles.deleteBuffers(1, &vertex_buffer);

        const position_attribute_location = std.math.cast(gles.GLuint, gles.getAttribLocation(shader_program, "vPosition")) catch return error.GraphicsApiFailure;
        const color_attribute_location = std.math.cast(gles.GLuint, gles.getAttribLocation(shader_program, "vColor")) catch return error.GraphicsApiFailure;
        const uv_attribute_location = std.math.cast(gles.GLuint, gles.getAttribLocation(shader_program, "vUV")) catch return error.GraphicsApiFailure;

        gles.enableVertexAttribArray(position_attribute_location);
        gles.enableVertexAttribArray(color_attribute_location);
        gles.enableVertexAttribArray(uv_attribute_location);

        gles.bindBuffer(gles.ARRAY_BUFFER, vertex_buffer);
        gles.vertexAttribPointer(position_attribute_location, 2, gles.FLOAT, gles.FALSE, @sizeOf(Vertex), @intToPtr(?*const c_void, @byteOffsetOf(Vertex, "x")));
        gles.vertexAttribPointer(color_attribute_location, 4, gles.UNSIGNED_BYTE, gles.TRUE, @sizeOf(Vertex), @intToPtr(?*const c_void, @byteOffsetOf(Vertex, "r")));
        gles.vertexAttribPointer(uv_attribute_location, 2, gles.FLOAT, gles.FALSE, @sizeOf(Vertex), @intToPtr(?*const c_void, @byteOffsetOf(Vertex, "u")));

        return Self{
            .shader_program = shader_program,
            .screen_size_location = gles.getUniformLocation(shader_program, "uScreenSize"),
            .texture_enable_location = gles.getUniformLocation(shader_program, "uTextureEnable"),
            .texture_location = gles.getUniformLocation(shader_program, "uTexture"),
            .vertices = std.ArrayList(Vertex).init(allocator),
            .vertex_buffer = vertex_buffer,
            .position_attribute_location = position_attribute_location,
            .color_attribute_location = color_attribute_location,
            .uv_attribute_location = uv_attribute_location,
            .allocator = allocator,
            .textures = .{},
            .draw_calls = std.ArrayList(DrawCall).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        while (self.textures.first) |tex| {
            self.destroyTextureInternal(tex);
        }
        gles.deleteBuffers(1, &self.vertex_buffer);
        gles.deleteProgram(self.shader_program);
        self.draw_calls.deinit();
        self.vertices.deinit();
        self.* = undefined;
    }

    /// Creates a new texture for this renderer with the size `width`×`height`.
    /// The texture is only valid as long as the renderer is valid *or* `destroyTexture` is called,
    /// whichever happens first.
    /// If `initial_data` is given, the data is encoded as BGRA pixels.
    pub fn createTexture(self: *Self, width: u15, height: u15, initial_data: ?[]const u8) !*const Texture {
        var id: gles.GLuint = undefined;
        gles.genTextures(1, &id);
        if (id == 0)
            return error.GraphicsApiFailure;

        gles.bindTexture(gles.TEXTURE_2D, id);
        if (initial_data) |data| {
            std.debug.assert(data.len == 4 * @as(usize, width) * @as(usize, height));
            gles.texImage2D(gles.TEXTURE_2D, 0, gles.RGBA, width, height, 0, gles.RGBA, gles.UNSIGNED_BYTE, data.ptr);
        } else {
            gles.texImage2D(gles.TEXTURE_2D, 0, gles.RGBA, width, height, 0, gles.RGBA, gles.UNSIGNED_BYTE, null);
        }
        gles.texParameteri(gles.TEXTURE_2D, gles.TEXTURE_MIN_FILTER, gles.LINEAR);
        gles.texParameteri(gles.TEXTURE_2D, gles.TEXTURE_MAG_FILTER, gles.LINEAR);

        const tex_node = try self.allocator.create(TextureItem);
        tex_node.* = .{
            .data = Texture{
                .handle = id,
                .refcount = 1,
                .width = width,
                .height = height,
            },
        };
        self.textures.append(tex_node);
        return &tex_node.data;
    }

    fn makeTextureMut(ptr: *const Texture) *Texture {
        return @intToPtr(*Texture, @ptrToInt(ptr));
    }

    /// Destroys a texture and releases all of its memory.
    /// The texture passed here must be created with `createTexture`.
    pub fn destroyTexture(self: *Self, texture: *const Texture) void {
        // we can do this as texture handles are only given out via `createTexture` which
        // returns a immutable reference.
        const mut_texture = makeTextureMut(texture);
        const node = @fieldParentPtr(TextureItem, "data", mut_texture);
        destroyTextureInternal(self, node);
    }

    fn destroyTextureInternal(self: *Self, node: *TextureItem) void {
        node.data.refcount -= 1;
        if (node.data.refcount > 0)
            return;

        self.textures.remove(node);

        gles.deleteTextures(1, &node.data.handle);
        node.* = undefined;

        self.allocator.destroy(node);
    }

    /// Updates the texture data of the given texture.
    /// `data` is encoded as BGRA pixels.
    pub fn updateTexture(self: *Self, texture: *Texture, data: []const u8) void {
        std.debug.assert(data.len == 4 * @as(usize, texture.width) * @as(usize, texture.height));
        gles.bindTexture(gles.TEXTURE_2D, texture.handle);
        gles.texImage2D(gles.TEXTURE_2D, 0, gles.RGBA, width, height, 0, gles.RGBA, gles.UNSIGNED_BYTE, data.ptr);
    }

    /// Resets the state of the renderer and prepares a fresh new frame.
    pub fn reset(self: *Self) void {
        for (self.draw_calls.items) |draw_call| {
            if (draw_call.texture) |tex| {
                self.destroyTexture(tex);
            }
        }
        self.draw_calls.shrinkRetainingCapacity(0);
        self.vertices.shrinkRetainingCapacity(0);
    }

    /// Renders the currently contained data to the screen.
    pub fn render(self: Self, width: u15, height: u15) void {
        gles.bindBuffer(gles.ARRAY_BUFFER, self.vertex_buffer);
        gles.bufferData(gles.ARRAY_BUFFER, @intCast(gles.GLsizeiptr, @sizeOf(Vertex) * self.vertices.items.len), self.vertices.items.ptr, gles.STATIC_DRAW);

        gles.useProgram(self.shader_program);
        gles.uniform2i(self.screen_size_location, width, height);
        gles.uniform1i(self.texture_location, 0);

        gles.enable(gles.BLEND);
        gles.blendFunc(gles.SRC_ALPHA, gles.ONE_MINUS_SRC_ALPHA);
        gles.blendEquation(gles.FUNC_ADD);

        gles.activeTexture(gles.TEXTURE0);
        for (self.draw_calls.items) |draw_call| {
            if (draw_call.texture) |tex_ptr| {
                gles.bindTexture(gles.TEXTURE_2D, tex_ptr.handle);
                gles.uniform1f(self.texture_enable_location, 1);
            } else {
                gles.bindTexture(gles.TEXTURE_2D, 0);
                gles.uniform1f(self.texture_enable_location, 0);
            }

            gles.drawArrays(
                gles.TRIANGLES,
                @intCast(gles.GLsizei, draw_call.offset),
                @intCast(gles.GLsizei, draw_call.count),
            );
        }
        gles.bindTexture(gles.TEXTURE_2D, 0);
    }

    /// Appends a set of triangles to the renderer with the given `texture`. 
    pub fn appendTriangles(self: *Self, texture: ?*const Texture, triangles: []const [3]Vertex) !void {
        const draw_call = if (self.draw_calls.items.len == 0 or self.draw_calls.items[self.draw_calls.items.len - 1].texture != texture) blk: {
            const dc = try self.draw_calls.addOne();
            dc.* = DrawCall{
                .texture = texture,
                .offset = self.vertices.items.len,
                .count = 0,
            };
            if (texture) |tex_ptr| {
                makeTextureMut(tex_ptr).refcount += 1;
            }
            break :blk dc;
        } else &self.draw_calls.items[self.draw_calls.items.len - 1];

        std.debug.assert(draw_call.texture == texture);

        try self.vertices.ensureCapacity(self.vertices.items.len + 3 * triangles.len);
        for (triangles) |tris| {
            try self.vertices.appendSlice(&tris);
        }

        draw_call.count += 3 * triangles.len;
    }

    /// Appends a filled, untextured quad.
    pub fn fillRectangle(self: *Self, x: i16, y: i16, width: u15, height: u15, color: Color) CollectError!void {
        const tl = Vertex.init(x, y, color).offset(-1, -1);
        const tr = Vertex.init(x + width - 1, y, color).offset(1, -1);
        const bl = Vertex.init(x, y + height - 1, color).offset(-1, 1);
        const br = Vertex.init(x + width - 1, y + height - 1, color).offset(1, 1);

        try self.appendTriangles(null, &[_][3]Vertex{
            .{ tl, br, tr },
            .{ br, tl, bl },
        });
    }

    /// Copies the given texture to the screen
    pub fn fillTexturedRectangle(self: *Self, x: i16, y: i16, width: u15, height: u15, texture: *const Texture, tint: ?Color) CollectError!void {
        const color = tint orelse Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = 0xFF };
        const tl = Vertex.init(x, y, color).offset(-1, -1).withUV(0, 0);
        const tr = Vertex.init(x + width - 1, y, color).offset(1, -1).withUV(1, 0);
        const bl = Vertex.init(x, y + height - 1, color).offset(-1, 1).withUV(0, 1);
        const br = Vertex.init(x + width - 1, y + height - 1, color).offset(1, 1).withUV(1, 1);

        try self.appendTriangles(texture, &[_][3]Vertex{
            .{ tl, br, tr },
            .{ br, tl, bl },
        });
    }

    /// Appends a rectangle with a 1 pixel wide outline
    pub fn drawRectangle(self: *Self, x: i16, y: i16, width: u15, height: u15, color: Color) CollectError!void {
        const tl = Vertex.init(x, y, color);
        const tr = Vertex.init(x + width - 1, y, color);
        const bl = Vertex.init(x, y + height - 1, color);
        const br = Vertex.init(x + width - 1, y + height - 1, color);

        try self.appendTriangles(null, &[_][3]Vertex{
            // top
            .{ tl.offset(-1, -1), tr.offset(-1, 1), tr.offset(1, -1) },
            .{ tr.offset(-1, 1), tl.offset(-1, -1), tl.offset(1, 1) },
            // right
            .{ tr.offset(1, -1), tr.offset(-1, 1), br.offset(-1, -1) },
            .{ br.offset(-1, -1), br.offset(1, 1), tr.offset(1, -1) },
            // bottom
            .{ br.offset(-1, -1), bl.offset(-1, 1), br.offset(1, 1) },
            .{ br.offset(-1, -1), bl.offset(1, -1), bl.offset(-1, 1) },
            // left
            .{ bl.offset(1, -1), tl.offset(-1, -1), bl.offset(-1, 1) },
            .{ bl.offset(1, 1), tl.offset(1, 1), tl.offset(-1, -1) },
        });
    }

    /// Draws a single pixel wide line from (`x0`,`y0`) to (`x1`,`y1`)
    pub fn drawLine(self: *Self, x0: i16, y0: i16, x1: i16, y1: i16, color: Color) CollectError!void {
        const p0 = Vertex.init(x0, y0, color);
        const p1 = Vertex.init(x1, y1, color);

        const dx = p1.x - p0.x;
        const dy = p1.y - p0.y;

        const len = std.math.sqrt(dx * dx + dy * dy);

        const ox_x = dx / len;
        const ox_y = dy / len;

        const oy_x = ox_y;
        const oy_y = -ox_x;

        try self.appendTriangles(null, &[_][3]Vertex{
            .{
                p0.offset(-ox_x, -ox_y).offset(-oy_x, -oy_y),
                p1.offset(ox_x, ox_y).offset(-oy_x, -oy_y),
                p1.offset(ox_x, ox_y).offset(oy_x, oy_y),
            },
            .{
                p0.offset(-ox_x, -ox_y).offset(-oy_x, -oy_y),
                p1.offset(ox_x, ox_y).offset(oy_x, oy_y),
                p0.offset(-ox_x, -ox_y).offset(oy_x, oy_y),
            },
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
