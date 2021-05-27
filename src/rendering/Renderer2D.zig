const std = @import("std");
const gles = @import("../gl_es_2v0.zig");
const types = @import("../types.zig");

const c = @cImport({
    @cInclude("stb_truetype.h");
});

const zigimg = @import("zigimg");

const Self = @This();

const Color = types.Color;
const Rectangle = types.Rectangle;
const Size = types.Size;

const TextureList = std.TailQueue(Texture);
const TextureItem = std.TailQueue(Texture).Node;

const FontList = std.TailQueue(Font);
const FontItem = std.TailQueue(Font).Node;

const CollectError = error{OutOfMemory};
const CreateTextureError = error{ OutOfMemory, GraphicsApiFailure };
const LoadTextureError = CreateTextureError || error{InvalidImageData};
const CreateFontError = error{ OutOfMemory, InvalidFontFile };
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
    \\uniform sampler2D uTexture;
    \\void main()
    \\{
    \\   vec4 base_color = texture2D(uTexture, fUV);
    \\   gl_FragColor = fColor * base_color;
    \\}
;

shader_program: gles.GLuint,
screen_size_location: gles.GLint,
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
fonts: FontList,

white_texture: *const Texture,

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

    var self = Self{
        .shader_program = shader_program,
        .screen_size_location = gles.getUniformLocation(shader_program, "uScreenSize"),
        .texture_location = gles.getUniformLocation(shader_program, "uTexture"),
        .vertices = std.ArrayList(Vertex).init(allocator),
        .vertex_buffer = vertex_buffer,
        .position_attribute_location = position_attribute_location,
        .color_attribute_location = color_attribute_location,
        .uv_attribute_location = uv_attribute_location,
        .allocator = allocator,
        .textures = .{},
        .fonts = .{},
        .draw_calls = std.ArrayList(DrawCall).init(allocator),
        .white_texture = undefined,
    };

    self.white_texture = try self.createTexture(2, 2, &([1]u8{0xFF} ** 16));

    return self;
}

pub fn deinit(self: *Self) void {
    // Fonts must be destroyed before textures
    // as fonts store textures internally
    while (self.fonts.first) |font| {
        self.destroyFontInternal(font);
    }
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
pub fn createTexture(self: *Self, width: u15, height: u15, initial_data: ?[]const u8) CreateTextureError!*const Texture {
    const tex_node = try self.allocator.create(TextureItem);
    errdefer self.allocator.destroy(tex_node);

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

/// Loads a texture from the given `image_data`. It should contain the file data as it would
/// be on disk, encoded as PNG. Other file formats might be supported,
/// but only PNG has official support.
pub fn loadTexture(self: *Self, image_data: []const u8) LoadTextureError!*const Texture {
    var image = zigimg.image.Image.fromMemory(self.allocator, image_data) catch return LoadTextureError.InvalidImageData;
    defer image.deinit();

    var buffer = try self.allocator.alloc(u8, 4 * image.width * image.height);
    defer self.allocator.free(buffer);

    var i: usize = 0;
    var pixels = image.iterator();
    while (pixels.next()) |pix| {
        const p8 = pix.toIntegerColor8();
        buffer[4 * i + 0] = p8.R;
        buffer[4 * i + 1] = p8.G;
        buffer[4 * i + 2] = p8.B;
        buffer[4 * i + 3] = p8.A;
        i += 1;
    }
    std.debug.assert(i == image.width * image.height);

    return try self.createTexture(
        @intCast(u15, image.width),
        @intCast(u15, image.height),
        buffer,
    );
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

/// Creates a new font from `ttf_bytes`. The bytes passed must be a valid TTF
pub fn createFont(self: *Self, ttf_bytes: []const u8, pixel_size: u15) CreateFontError!*const Font {
    var info = std.mem.zeroes(c.stbtt_fontinfo);
    info.userdata = self.allocator;

    const offset = c.stbtt_GetFontOffsetForIndex(ttf_bytes.ptr, 0);
    if (offset < 0)
        return error.InvalidFontFile;

    if (c.stbtt_InitFont(&info, ttf_bytes.ptr, offset) == 0)
        return error.InvalidFontFile;

    var ascent: c_int = undefined;
    var descent: c_int = undefined;
    var line_gap: c_int = undefined;
    c.stbtt_GetFontVMetrics(&info, &ascent, &descent, &line_gap);

    var font = try self.allocator.create(FontItem);
    errdefer self.allocator.destroy(font);

    font.* = .{
        .data = Font{
            .refcount = 1,
            .font = info,
            .allocator = self.allocator,
            .arena = std.heap.ArenaAllocator.init(self.allocator),
            .glyphs = std.AutoHashMap(u24, Glyph).init(self.allocator),
            .font_size = pixel_size,
            .ascent = @intCast(i16, ascent),
            .descent = @intCast(i16, descent),
            .line_gap = @intCast(i16, line_gap),
            .scale = c.stbtt_ScaleForPixelHeight(&info, @intToFloat(f32, pixel_size)),
        },
    };

    self.fonts.append(font);

    return &font.data;
}

fn makeFontMut(ptr: *const Font) *Font {
    return @intToPtr(*Font, @ptrToInt(ptr));
}

/// Destroys a font and releases all of its memory.
/// The font passed here must be created with `createFont`.
pub fn destroyFont(self: *Self, font: *const Font) void {
    // we can do this as texture handles are only given out via `createFont` which
    // returns a immutable reference.
    const mut_font = makeFontMut(font);
    const node = @fieldParentPtr(FontItem, "data", mut_font);
    destroyFontInternal(self, node);
}

fn destroyFontInternal(self: *Self, node: *FontItem) void {
    node.data.refcount -= 1;
    if (node.data.refcount > 0)
        return;

    self.fonts.remove(node);

    var iter = node.data.glyphs.iterator();
    while (iter.next()) |glyph| {
        self.destroyTexture(glyph.value.texture);
    }

    node.data.glyphs.deinit();
    node.data.arena.deinit();

    node.* = undefined;

    self.allocator.destroy(node);
}

fn getGlyph(self: *Self, font: *Font, codepoint: u24) !Glyph {
    var gop = try font.glyphs.getOrPut(codepoint);
    if (!gop.found_existing) {
        var ix0: c_int = undefined;
        var iy0: c_int = undefined;
        var ix1: c_int = undefined;
        var iy1: c_int = undefined;

        c.stbtt_GetCodepointBitmapBox(
            &font.font,
            codepoint,
            font.scale,
            font.scale,
            &ix0,
            &iy0,
            &ix1,
            &iy1,
        );
        std.debug.assert(ix0 <= ix1);
        std.debug.assert(iy0 <= iy1);

        const width: u15 = @intCast(u15, ix1 - ix0);
        const height: u15 = @intCast(u15, iy1 - iy0);

        const bitmap = try font.arena.allocator.alloc(u8, @as(usize, width) * height);
        errdefer font.arena.allocator.free(bitmap);

        c.stbtt_MakeCodepointBitmap(
            &font.font,
            bitmap.ptr,
            @intCast(c_int, width),
            @intCast(c_int, height),
            @intCast(c_int, width), // stride
            font.scale,
            font.scale,
            codepoint,
        );

        var advance_width: c_int = undefined;
        var left_side_bearing: c_int = undefined;
        c.stbtt_GetCodepointHMetrics(&font.font, codepoint, &advance_width, &left_side_bearing);

        const texture_data = try self.allocator.alloc(u8, 4 * @as(usize, width) * height);
        defer self.allocator.free(texture_data);

        for (bitmap) |a, i| {
            const o = 4 * i;
            texture_data[o + 0] = 0xFF;
            texture_data[o + 1] = 0xFF;
            texture_data[o + 2] = 0xFF;
            texture_data[o + 3] = a;
        }

        var texture = try self.createTexture(width, height, texture_data);
        errdefer self.destroyTexture(texture);

        // std.debug.print("{d} ({},{}) ({},{}) {}×{} {} {}\n", .{
        //     scale,
        //     ix0,
        //     iy0,
        //     ix1,
        //     iy1,
        //     width,
        //     height,
        //     advance_width,
        //     left_side_bearing,
        // });

        var glyph = Glyph{
            .texture = texture,
            .pixels = bitmap,
            .width = width,
            .height = height,
            .advance_width = @intCast(i16, advance_width),
            .left_side_bearing = @intCast(i16, left_side_bearing),
            .offset_y = @intCast(i16, iy0),
        };

        gop.entry.value = glyph;
    }
    return gop.entry.value;
}

fn scaleInt(ival: isize, scale: f32) i16 {
    return @intCast(i16, @floatToInt(isize, std.math.round(@intToFloat(f32, ival) * scale)));
}

const GlyphIterator = struct {
    renderer: *Self,
    font: *Font,
    codepoint_src: std.unicode.Utf8Iterator,

    dx: i16,
    dy: i16,

    previous_codepoint: ?u21 = null,

    pub fn init(renderer: *Self, font: *Font, text: []const u8) GlyphIterator {
        return GlyphIterator{
            .renderer = renderer,
            .font = font,
            .codepoint_src = std.unicode.Utf8Iterator{
                .bytes = text,
                .i = 0,
            },

            .dx = 0,
            .dy = scaleInt(font.ascent, font.scale),
        };
    }

    pub fn next(self: *GlyphIterator) ?GlyphCmd {
        while (true) {
            const codepoint = self.codepoint_src.nextCodepoint() orelse return null;
            if (codepoint == '\n') {
                self.dx = 0;
                self.dy += self.font.getLineHeight();
                self.previous_codepoint = null;
                continue;
            }

            const glyph = self.renderer.getGlyph(self.font, codepoint) catch continue;

            if (self.previous_codepoint) |prev| {
                self.dx += @intCast(i16, c.stbtt_GetCodepointKernAdvance(&self.font.font, prev, codepoint));
            }
            self.previous_codepoint = codepoint;

            const off_x = scaleInt(self.dx + glyph.left_side_bearing, self.font.scale);
            const off_y = glyph.offset_y + self.dy;

            self.dx += glyph.advance_width;

            return GlyphCmd{
                .codepoint = codepoint,
                .x = off_x,
                .y = off_y,
                .width = glyph.width,
                .height = glyph.height,
                .texture = glyph.texture,
            };
        }
    }

    const GlyphCmd = struct {
        codepoint: u21,
        texture: *const Texture,
        x: i16,
        y: i16,
        width: u15,
        height: u15,
    };
};

/// Measures the extends of the given `text` when rendered with `font`.
/// Returns the size and relative offset the string will take up on the screen.
/// Returned values are in pixels.
pub fn measureString(self: *Self, font: *const Font, text: []const u8) Rectangle {
    var max_dx: i16 = 0;
    var max_dy: i16 = 0;

    var min_dx: i16 = 0;
    var min_dy: i16 = 0;

    var iterator = GlyphIterator.init(self, makeFontMut(font), text);
    while (iterator.next()) |glyph| {
        min_dx = std.math.min(min_dx, glyph.x);
        min_dy = std.math.min(min_dy, glyph.y);
        max_dx = std.math.max(max_dx, glyph.x + glyph.width);
        max_dy = std.math.max(max_dy, glyph.y + glyph.height);
    }

    return Rectangle{
        .x = min_dx,
        .y = min_dy,
        .width = @intCast(u15, max_dx - min_dx),
        .height = @intCast(u15, max_dy - min_dy),
    };
}

/// Draws the given `text` to local (`x`,`y`) with `color` applied.
/// The final size of the string can be computed with `measureString()`.
/// This is a low-level function that does not do any kind of pre-computation. It will just render what it
/// was given. If a more advanced rendering is required, use `drawText()` instead!
pub fn drawString(self: *Self, font: *const Font, text: []const u8, x: i16, y: i16, color: Color) !void {
    var iterator = GlyphIterator.init(self, makeFontMut(font), text);
    while (iterator.next()) |glyph| {
        try self.fillTexturedRectangle(
            Rectangle{
                .x = x + glyph.x,
                .y = y + glyph.y,
                .width = glyph.width,
                .height = glyph.height,
            },
            glyph.texture,
            color,
        );
    }
}

// TODO: Implement a proper `drawText()`
// pub const DrawTextOptions = struct {
//     color: Color,
//     vertical_alignment: types.VerticalAlignment = .left,
//     horizontal_alignment: types.HorzizontalAlignment = .top,
//     max_width: ?u15 = null,
//     max_height: ?u15 = null,
// };

// /// Draws the given `text` into `rectangle` using the layout configuration in `options`.
// /// Text will only be drawn when full glyphs fit the area specified via `max_width` and `max_height`.
// /// This function a lot more computation than two calls to `measureString()` and `drawString()`, so it should only
// /// be used when proper text layouting is required.
// pub fn drawText(self: *Self, font: *const Font, text: []const u8, x: i16, y: i16, options: DrawTextOptions) !void {
//     var total_width: u15 = 0;
//     var total_height: u15 = 0;
//     var line_count: usize = 0;

//     const line_height = font.getLineHeight();

//     var lines_iter = std.mem.split(text, "\n");
//     while (lines_iter.next()) |line| {
//         if (options.max_height) |limit| {
//             if (total_height + line_height > limit)
//                 break;
//         }
//         total_width += self.measureString(font, line).width;
//         total_height += line_height;
//         line_count += 1;
//     }

//     const offset_x: i16 = switch (options.vertical_alignment) {
//         .left => @as(i16, 0),
//         .center => -@as(i16, total_width / 2),
//         .right => -@as(i16, total_width),
//     };
//     const offset_y = switch (options.vertical_alignment) {
//         .top => @as(i16, 0),
//         .center => -@as(i16, total_height / 2),
//         .bottom => -@as(i16, total_height),
//     };

//     var dy: u15 = 0;

//     var i: usize = 0;
//     lines_iter = td.mem.split(text, "\n");
//     while (lines_iter.next()) |line| {
//         i += 1;
//         if (i >= line_count) // would draw outside max_height
//             break;
//         const width = self.measureString(font, line).width;

//         const dx = switch(options.horizontal_alignment) {
//             .left => @as(i16,0),
//             .center => -@as(i16, total_width / 2),
//         };
//     }
// }

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
        const tex_handle = draw_call.texture orelse self.white_texture;

        gles.bindTexture(gles.TEXTURE_2D, tex_handle.handle);

        gles.drawArrays(
            gles.TRIANGLES,
            @intCast(gles.GLsizei, draw_call.offset),
            @intCast(gles.GLsizei, draw_call.count),
        );
    }
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
pub fn fillRectangle(self: *Self, rectangle: Rectangle, color: Color) CollectError!void {
    const tl = Vertex.init(rectangle.x, rectangle.y, color).offset(-1, -1);
    const tr = Vertex.init(rectangle.x + rectangle.width - 1, rectangle.y, color).offset(1, -1);
    const bl = Vertex.init(rectangle.x, rectangle.y + rectangle.height - 1, color).offset(-1, 1);
    const br = Vertex.init(rectangle.x + rectangle.width - 1, rectangle.y + rectangle.height - 1, color).offset(1, 1);

    try self.appendTriangles(null, &[_][3]Vertex{
        .{ tl, br, tr },
        .{ br, tl, bl },
    });
}

/// Copies the given texture to the screen
pub fn fillTexturedRectangle(self: *Self, rectangle: Rectangle, texture: *const Texture, tint: ?Color) CollectError!void {
    const color = tint orelse Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = 0xFF };
    const tl = Vertex.init(rectangle.x, rectangle.y, color).offset(-1, -1).withUV(0, 0);
    const tr = Vertex.init(rectangle.x + rectangle.width - 1, rectangle.y, color).offset(1, -1).withUV(1, 0);
    const bl = Vertex.init(rectangle.x, rectangle.y + rectangle.height - 1, color).offset(-1, 1).withUV(0, 1);
    const br = Vertex.init(rectangle.x + rectangle.width - 1, rectangle.y + rectangle.height - 1, color).offset(1, 1).withUV(1, 1);

    try self.appendTriangles(texture, &[_][3]Vertex{
        .{ tl, br, tr },
        .{ br, tl, bl },
    });
}

/// Appends a rectangle with a 1 pixel wide outline
pub fn drawRectangle(self: *Self, rectangle: Rectangle, color: Color) CollectError!void {
    const tl = Vertex.init(rectangle.x, rectangle.y, color);
    const tr = Vertex.init(rectangle.x + rectangle.width - 1, rectangle.y, color);
    const bl = Vertex.init(rectangle.x, rectangle.y + rectangle.height - 1, color);
    const br = Vertex.init(rectangle.x + rectangle.width - 1, rectangle.y + rectangle.height - 1, color);

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

pub const Font = struct {

    /// private reference counter.
    /// This is required as texture references are held in the internal draw 
    /// queue when passing them into a draw command and will be released after
    /// the `render()` call
    refcount: usize,

    font: c.stbtt_fontinfo,
    allocator: *std.mem.Allocator,
    arena: std.heap.ArenaAllocator,
    glyphs: std.AutoHashMap(u24, Glyph),

    font_size: u15,

    ascent: i16,
    descent: i16,
    line_gap: i16,

    /// Scale of `advance_width` and `left_side_bearing`
    scale: f32,

    /// Returns the height of a single text line of this font
    pub fn getLineHeight(self: Font) u15 {
        return @intCast(u15, scaleInt(self.ascent - self.descent + self.line_gap, self.scale));
    }
};

// get the bbox of the bitmap centered around the glyph origin; so the
// bitmap width is ix1-ix0, height is iy1-iy0, and location to place
// the bitmap top left is (leftSideBearing*scale,iy0).
// (Note that the bitmap uses y-increases-down, but the shape uses
// y-increases-up, so CodepointBitmapBox and CodepointBox are inverted.)

pub const Glyph = struct {
    /// row-major grayscale pixels of the target map
    pixels: []u8,

    /// width of the image in pixels
    width: u15,

    /// height of the image in pixels
    height: u15,

    /// offset to the base line
    offset_y: i16,

    /// advanceWidth is the offset from the current horizontal position to the next horizontal position
    /// these are expressed in unscaled coordinates
    advance_width: i16,

    /// leftSideBearing is the offset from the current horizontal position to the left edge of the character
    left_side_bearing: i16,

    texture: *const Texture,

    fn getAlpha(self: Glyph, x: u15, y: u15) u8 {
        if (x >= self.width or y >= self.height)
            return 0;

        return self.pixels[@as(usize, std.math.absCast(y)) * self.width + @as(usize, std.math.absCast(x))];
    }
};

export fn zerog_renderer2d_alloc(user_data: ?*c_void, size: usize) ?*c_void {
    const allocator = @ptrCast(*std.mem.Allocator, @alignCast(@alignOf(std.mem.Allocator), user_data orelse @panic("unexpected NULl!")));

    const buffer = allocator.allocAdvanced(u8, 16, size + 16, .exact) catch return null;
    std.mem.writeIntNative(usize, buffer[0..@sizeOf(usize)], buffer.len);
    return buffer.ptr + 16;
}

export fn zerog_renderer2d_free(user_data: ?*c_void, ptr: ?*c_void) void {
    const allocator = @ptrCast(*std.mem.Allocator, @alignCast(@alignOf(std.mem.Allocator), user_data orelse @panic("unexpected NULl!")));

    const actual_buffer = @ptrCast([*]u8, ptr orelse return) - 16;
    const len = std.mem.readIntNative(usize, actual_buffer[0..@sizeOf(usize)]);

    allocator.free(actual_buffer[0..len]);
}
