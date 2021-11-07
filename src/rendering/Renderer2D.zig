const std = @import("std");
const gles = @import("../gl_es_2v0.zig");
const types = @import("../zero-graphics.zig");
const logger = std.log.scoped(.zerog_renderer2D);

const glesh = @import("gles-helper.zig");

const c = @cImport({
    @cInclude("stb_truetype.h");
});

const zigimg = @import("zigimg");

const ResourceManager = @import("ResourceManager.zig");

const Self = @This();

const Color = types.Color;
const Rectangle = types.Rectangle;
const Size = types.Size;
const Point = types.Point;

const FontList = std.TailQueue(Font);
const FontItem = std.TailQueue(Font).Node;

pub const DrawError = error{OutOfMemory};
pub const CreateFontError = error{ OutOfMemory, InvalidFontFile };
pub const InitError = error{ OutOfMemory, GraphicsApiFailure } || ResourceManager.CreateResourceDataError;

/// Vertex attributes used in this renderer
const vertex_attributes = .{
    .vPosition = 0,
    .vColor = 1,
    .vUV = 2,
};

const Uniforms = struct {
    uScreenSize: gles.GLint,
    uTexture: gles.GLint,
};

shader_program: *ResourceManager.Shader,
// uniforms: Uniforms,

vertex_buffer: *ResourceManager.Buffer,

/// list of CCW triangles that will be rendered 
vertices: std.ArrayList(Vertex),
draw_calls: std.ArrayList(DrawCall),

allocator: *std.mem.Allocator,

fonts: FontList,

resources: *ResourceManager,
white_texture: *ResourceManager.Texture,

/// Scales all input coordinates with this factor.
/// This can be used for DPI scaling.
/// A value of `2.0` means that `1 unit` is equal to `2 pixels`
unit_to_pixel_ratio: f32 = 1.0,

pub fn init(resources: *ResourceManager, allocator: *std.mem.Allocator) InitError!Self {
    const shader_program = try resources.createShader(ResourceManager.BasicShader{
        .vertex_shader = vertexSource,
        .fragment_shader = fragmentSource,
        .attributes = glesh.attributes(vertex_attributes),
    });
    errdefer resources.destroyShader(shader_program);

    const vertex_buffer = try resources.createBuffer(ResourceManager.EmptyBuffer{});
    errdefer resources.destroyBuffer(vertex_buffer);

    var self = Self{
        .resources = resources,
        .shader_program = shader_program,
        // .uniforms = glesh.fetchUniforms(shader_program.instance.?, Uniforms),
        .vertices = std.ArrayList(Vertex).init(allocator),
        .vertex_buffer = vertex_buffer,

        .allocator = allocator,
        .fonts = .{},
        .draw_calls = std.ArrayList(DrawCall).init(allocator),
        .white_texture = undefined,
    };

    self.white_texture = try self.resources.createTexture(.@"3d", ResourceManager.FlatTexture{
        .width = 2,
        .height = 2,
        .color = .{ .r = 0xFF, .g = 0xFF, .b = 0xFF },
    });

    return self;
}

pub fn deinit(self: *Self) void {
    self.reset();

    // Fonts must be destroyed before textures
    // as fonts store textures internally
    while (self.fonts.first) |font| {
        self.destroyFontInternal(font);
    }

    self.resources.destroyBuffer(self.vertex_buffer);
    self.resources.destroyShader(self.shader_program);
    self.draw_calls.deinit();
    self.vertices.deinit();
    self.* = undefined;
}

pub fn getVirtualScreenSize(self: Self, physical_size: Size) Size {
    return Size{
        .width = @floatToInt(u15, 0.5 + @intToFloat(f32, physical_size.width) / self.unit_to_pixel_ratio),
        .height = @floatToInt(u15, 0.5 + @intToFloat(f32, physical_size.height) / self.unit_to_pixel_ratio),
    };
}

fn inverseScaleDimension(self: Self, size: u15) u15 {
    return @floatToInt(u15, 0.5 + @intToFloat(f32, size) / self.unit_to_pixel_ratio);
}

fn inverseScalePosition(self: Self, val: i16) i16 {
    return @floatToInt(i16, 0.5 + @intToFloat(f32, val) / self.unit_to_pixel_ratio);
}

fn scaleDimension(self: Self, size: u15) u15 {
    return @floatToInt(u15, 0.5 + self.unit_to_pixel_ratio * @intToFloat(f32, size));
}

fn scalePosition(self: Self, val: i16) i16 {
    return @floatToInt(i16, 0.5 + self.unit_to_pixel_ratio * @intToFloat(f32, val));
}

fn scalePoint(self: Self, pt: Point) Point {
    return Point{
        .x = self.scalePosition(pt.x),
        .y = self.scalePosition(pt.y),
    };
}

fn scaleSize(self: Self, size: Size) Size {
    return Size{
        .width = self.scaleDimension(size.width),
        .height = self.scaleDimension(size.height),
    };
}

fn scaleRectangle(self: Self, rect: Rectangle) Rectangle {
    return Rectangle{
        .x = self.scalePosition(rect.x),
        .y = self.scalePosition(rect.y),
        .width = self.scaleDimension(rect.width),
        .height = self.scaleDimension(rect.height),
    };
}

/// Creates a new font from `ttf_bytes`. The bytes passed must be a valid TTF
pub fn createFont(self: *Self, ttf_bytes: []const u8, size: u15) CreateFontError!*const Font {
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
            .font_size = size,
            .ascent = @intCast(i16, ascent),
            .descent = @intCast(i16, descent),
            .line_gap = @intCast(i16, line_gap),
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
    std.debug.assert(mut_font.refcount > 0);
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
        self.resources.destroyTexture(glyph.value_ptr.texture);
    }

    node.data.glyphs.deinit();
    node.data.arena.deinit();

    node.* = undefined;

    self.allocator.destroy(node);
}

fn getFontScale(self: Self, font: *const Font) f32 {
    return self.unit_to_pixel_ratio * c.stbtt_ScaleForPixelHeight(&font.font, @intToFloat(f32, font.font_size));
}

pub fn getGlyph(self: *Self, font: *const Font, codepoint: u21) !Glyph {
    return self.getGlyphInternal(makeFontMut(font), codepoint);
}

fn getGlyphInternal(self: *Self, font: *Font, codepoint: u21) !Glyph {
    var ix0: c_int = undefined;
    var iy0: c_int = undefined;
    var ix1: c_int = undefined;
    var iy1: c_int = undefined;

    // Scale of `advance_width` and `left_side_bearing`
    const scale = self.getFontScale(font);

    c.stbtt_GetCodepointBitmapBox(
        &font.font,
        codepoint,
        scale,
        scale,
        &ix0,
        &iy0,
        &ix1,
        &iy1,
    );
    std.debug.assert(ix0 <= ix1);
    std.debug.assert(iy0 <= iy1);

    const width: u15 = @intCast(u15, ix1 - ix0);
    const height: u15 = @intCast(u15, iy1 - iy0);

    var gop = try font.glyphs.getOrPut(codepoint);
    if (!gop.found_existing or gop.value_ptr.width != width or gop.value_ptr.height != height) {
        const bitmap = try font.arena.allocator.alloc(u8, @as(usize, width) * height);
        errdefer font.arena.allocator.free(bitmap);

        c.stbtt_MakeCodepointBitmap(
            &font.font,
            bitmap.ptr,
            @intCast(c_int, width),
            @intCast(c_int, height),
            @intCast(c_int, width), // stride
            scale,
            scale,
            codepoint,
        );

        var advance_width: c_int = undefined;
        var left_side_bearing: c_int = undefined;
        c.stbtt_GetCodepointHMetrics(&font.font, codepoint, &advance_width, &left_side_bearing);

        const texture_data = try font.arena.allocator.alloc(u8, 4 * @as(usize, width) * height);
        errdefer font.arena.allocator.free(texture_data);

        for (bitmap) |a, i| {
            const o = 4 * i;
            texture_data[o + 0] = 0xFF;
            texture_data[o + 1] = 0xFF;
            texture_data[o + 2] = 0xFF;
            texture_data[o + 3] = a;
        }

        var texture = try self.resources.createTexture(.ui, ResourceManager.RawRgbaTexture{
            .width = width,
            .height = height,
            .pixels = texture_data,
        });
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

        // var buf: [8]u8 = undefined;
        // const len = try std.unicode.utf8Encode(codepoint, &buf);
        // var codepoint_str = buf[0..len];

        if (gop.found_existing) {
            // logger.info("regenerate glyph '{s}' to {}×{}", .{ codepoint_str, width, height });
            self.resources.destroyTexture(gop.value_ptr.texture);
        } else {
            // logger.info("render glyph '{s}' to {}×{}", .{ codepoint_str, width, height });
        }

        gop.value_ptr.* = glyph;
    }
    return gop.value_ptr.*;
}

fn scaleInt(ival: isize, scale: f32) i16 {
    return @intCast(i16, @floatToInt(isize, std.math.round(@intToFloat(f32, ival) * scale)));
}

const GlyphIterator = struct {
    renderer: *Self,
    font: *Font,
    codepoint_src: std.unicode.Utf8Iterator,
    scale: f32,

    dx: isize,
    dy: i16,

    previous_codepoint: ?u21 = null,

    pub fn init(renderer: *Self, font: *Font, text: []const u8) GlyphIterator {
        const scale = renderer.getFontScale(font);

        return GlyphIterator{
            .renderer = renderer,
            .font = font,
            .codepoint_src = std.unicode.Utf8Iterator{
                .bytes = text,
                .i = 0,
            },

            .scale = scale,

            .dx = 0,
            .dy = scaleInt(font.ascent, scale),
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

            const off_x = scaleInt(self.dx + glyph.left_side_bearing, self.scale);
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
        texture: *ResourceManager.Texture,

        // coordinates are in physical screen space
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
        .x = self.inverseScalePosition(min_dx),
        .y = self.inverseScalePosition(min_dy),
        .width = self.inverseScaleDimension(@intCast(u15, max_dx - min_dx)),
        .height = self.inverseScaleDimension(@intCast(u15, max_dy - min_dy)),
    };
}

/// Draws the given `text` to local (`x`,`y`) with `color` applied.
/// The final size of the string can be computed with `measureString()`.
/// This is a low-level function that does not do any kind of pre-computation. It will just render what it
/// was given. If a more advanced rendering is required, use `drawText()` instead!
pub fn drawString(self: *Self, font: *const Font, text: []const u8, x: i16, y: i16, color: Color) DrawError!void {
    var iterator = GlyphIterator.init(self, makeFontMut(font), text);
    while (iterator.next()) |glyph| {
        try self.fillTexturedRectanglePixels(
            Rectangle{
                .x = self.scalePosition(x) + glyph.x,
                .y = self.scalePosition(y) + glyph.y,
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
        if (draw_call == .draw_vertices) {
            if (draw_call.draw_vertices.texture) |tex| {
                self.resources.destroyTexture(tex);
            }
        }
    }
    self.draw_calls.shrinkRetainingCapacity(0);
    self.vertices.shrinkRetainingCapacity(0);
}

/// Renders the currently contained data to the screen.
pub fn render(self: Self, screen_size: Size) void {
    glesh.enableAttributes(vertex_attributes);
    defer glesh.disableAttributes(vertex_attributes);

    gles.disable(gles.DEPTH_TEST);
    gles.enable(gles.BLEND);

    gles.bindBuffer(gles.ARRAY_BUFFER, self.vertex_buffer.instance.?);
    gles.bufferData(gles.ARRAY_BUFFER, @intCast(gles.GLsizeiptr, @sizeOf(Vertex) * self.vertices.items.len), self.vertices.items.ptr, gles.STATIC_DRAW);

    gles.vertexAttribPointer(vertex_attributes.vPosition, 2, gles.FLOAT, gles.FALSE, @sizeOf(Vertex), @intToPtr(?*const c_void, @offsetOf(Vertex, "x")));
    gles.vertexAttribPointer(vertex_attributes.vColor, 4, gles.UNSIGNED_BYTE, gles.TRUE, @sizeOf(Vertex), @intToPtr(?*const c_void, @offsetOf(Vertex, "r")));
    gles.vertexAttribPointer(vertex_attributes.vUV, 2, gles.FLOAT, gles.FALSE, @sizeOf(Vertex), @intToPtr(?*const c_void, @offsetOf(Vertex, "u")));

    var uniforms = glesh.fetchUniforms(self.shader_program.instance.?, Uniforms);

    gles.useProgram(self.shader_program.instance.?);
    gles.uniform2i(uniforms.uScreenSize, screen_size.width, screen_size.height);
    gles.uniform1i(uniforms.uTexture, 0);

    gles.blendFunc(gles.SRC_ALPHA, gles.ONE_MINUS_SRC_ALPHA);
    gles.blendEquation(gles.FUNC_ADD);

    gles.activeTexture(gles.TEXTURE0);

    const ClipStack = struct {
        const ClipStack = @This();

        screen_size: Size,
        rectangles: [16]Rectangle,
        size: usize = 0,

        fn actualClipRect(stack: ClipStack) ?Rectangle {
            const full_screen = Rectangle.init(Point.zero, stack.screen_size);

            var clip_rect = full_screen;
            for (stack.rectangles[0 .. stack.size + 1]) |rect| {
                const clip_right = clip_rect.x + clip_rect.width;
                const clip_bottom = clip_rect.y + clip_rect.height;
                const rect_right = rect.x + rect.width;
                const rect_bottom = rect.y + rect.height;

                const left = std.math.max(clip_rect.x, rect.x);
                const top = std.math.max(clip_rect.y, rect.y);
                const right = std.math.min(clip_right, rect_right);
                const bottom = std.math.min(clip_bottom, rect_bottom);

                const width = @intCast(u15, if (right > left) right - left else 0);
                const height = @intCast(u15, if (bottom > top) bottom - top else 0);

                clip_rect = Rectangle{
                    .x = left,
                    .y = top,
                    .width = width,
                    .height = height,
                };
                if (clip_rect.area() == 0)
                    break;
            }
            if (std.meta.eql(clip_rect, full_screen))
                return null;
            return clip_rect;
        }

        fn setClipState(stack: ClipStack) void {
            if (stack.actualClipRect()) |clip_rect| {
                gles.enable(gles.SCISSOR_TEST);
                gles.scissor(
                    clip_rect.x,
                    stack.screen_size.height - clip_rect.y - clip_rect.height - 1,
                    clip_rect.width,
                    clip_rect.height,
                );
            } else {
                gles.disable(gles.SCISSOR_TEST);
            }
        }
    };

    {
        var stack = ClipStack{
            .screen_size = screen_size,
            .rectangles = undefined,
        };
        stack.rectangles[0] = Rectangle.init(Point.zero, screen_size);
        defer gles.disable(gles.SCISSOR_TEST);
        for (self.draw_calls.items) |draw_call| {
            switch (draw_call) {
                .push_clip_rect => |rectangle| {
                    stack.size += 1;
                    stack.rectangles[stack.size] = rectangle;
                    stack.setClipState();
                },
                .pop_clip_rect => {
                    if (stack.size > 0) {
                        stack.size -= 1;
                    } else {
                        stack.rectangles[0] = Rectangle.init(Point.zero, screen_size);
                    }
                    stack.setClipState();
                },
                .set_clip_rect => |rectangle| {
                    stack.rectangles[stack.size] = rectangle;
                    stack.setClipState();
                },
                .clear_clip_rect => {
                    stack.rectangles[stack.size] = Rectangle.init(Point.zero, screen_size);
                    stack.setClipState();
                },

                .draw_vertices => |vertices| {
                    const tex_handle = vertices.texture orelse self.white_texture;

                    gles.bindTexture(gles.TEXTURE_2D, tex_handle.instance orelse 0);

                    gles.drawArrays(
                        gles.TRIANGLES,
                        @intCast(gles.GLsizei, vertices.offset),
                        @intCast(gles.GLsizei, vertices.count),
                    );
                },
            }
        }
    }
}

/// Appends a set of triangles to the renderer with the given `texture`. 
pub fn appendTriangles(self: *Self, texture: ?*ResourceManager.Texture, triangles: []const [3]Vertex) DrawError!void {
    const draw_call = if (self.draw_calls.items.len == 0 or self.draw_calls.items[self.draw_calls.items.len - 1] != .draw_vertices or self.draw_calls.items[self.draw_calls.items.len - 1].draw_vertices.texture != texture) blk: {
        const dc = try self.draw_calls.addOne();
        dc.* = DrawCall{
            .draw_vertices = DrawVertices{
                .texture = texture,
                .offset = self.vertices.items.len,
                .count = 0,
            },
        };
        if (texture) |tex_ptr| {
            self.resources.retainTexture(tex_ptr);
        }
        break :blk &dc.draw_vertices;
    } else &self.draw_calls.items[self.draw_calls.items.len - 1].draw_vertices;

    std.debug.assert(draw_call.texture == texture);

    try self.vertices.ensureCapacity(self.vertices.items.len + 3 * triangles.len);
    for (triangles) |tris| {
        try self.vertices.appendSlice(&tris);
    }

    draw_call.count += 3 * triangles.len;
}

/// Appends a filled, untextured quad.
/// ```
/// 0---1
/// |'\.|
/// 2---3
/// ```
pub fn fillQuad(self: *Self, corners: [4]Point, color: Color) DrawError!void {
    var real_corners: [4]Point = undefined;
    for (real_corners) |*dst, i| {
        dst.* = self.scalePoint(corners[i]);
    }
    return self.fillQuadPixels(real_corners, color);
}

pub fn fillQuadPixels(self: *Self, real_corners: [4]Point, color: Color) DrawError!void {

    // TODO: Gain pixel-perfection here!
    const p0 = Vertex.init(real_corners[0].x, real_corners[0].y, color);
    const p1 = Vertex.init(real_corners[1].x, real_corners[1].y, color);
    const p2 = Vertex.init(real_corners[2].x, real_corners[2].y, color);
    const p3 = Vertex.init(real_corners[3].x, real_corners[3].y, color);

    try self.appendTriangles(null, &[_][3]Vertex{
        .{ p0, p1, p2 },
        .{ p1, p3, p2 },
    });
}

/// Appends a filled, untextured quad.
pub fn fillRectangle(self: *Self, rectangle: Rectangle, color: Color) DrawError!void {
    return self.fillRectanglePixels(self.scaleRectangle(rectangle), color);
}

pub fn fillRectanglePixels(self: *Self, real_rect: Rectangle, color: Color) DrawError!void {
    if (real_rect.size().isEmpty())
        return;

    const tl = Vertex.init(real_rect.x, real_rect.y, color).offset(-1, -1);
    const tr = Vertex.init(real_rect.x + real_rect.width - 1, real_rect.y, color).offset(1, -1);
    const bl = Vertex.init(real_rect.x, real_rect.y + real_rect.height - 1, color).offset(-1, 1);
    const br = Vertex.init(real_rect.x + real_rect.width - 1, real_rect.y + real_rect.height - 1, color).offset(1, 1);

    try self.appendTriangles(null, &[_][3]Vertex{
        .{ tl, br, tr },
        .{ br, tl, bl },
    });
}

pub fn setPixel(self: *Self, x: i16, y: i16, color: Color) DrawError!void {
    try self.fillRectangle(Rectangle{
        .x = self.scaleDimension(x),
        .y = self.scaleDimension(y),
        .width = 1,
        .height = 1,
    }, color);
}

/// Copies the given texture to the screen
pub fn fillTexturedRectangle(self: *Self, rectangle: Rectangle, texture: *ResourceManager.Texture, tint: ?Color) DrawError!void {
    return self.fillTexturedRectanglePixels(self.scaleRectangle(rectangle), texture, tint);
}

pub fn fillTexturedRectanglePixels(self: *Self, real_rect: Rectangle, texture: *ResourceManager.Texture, tint: ?Color) DrawError!void {
    if (real_rect.size().isEmpty())
        return;

    const color = tint orelse Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = 0xFF };
    const tl = Vertex.init(real_rect.x, real_rect.y, color).offset(-1, -1).withUV(0, 0);
    const tr = Vertex.init(real_rect.x + real_rect.width - 1, real_rect.y, color).offset(1, -1).withUV(1, 0);
    const bl = Vertex.init(real_rect.x, real_rect.y + real_rect.height - 1, color).offset(-1, 1).withUV(0, 1);
    const br = Vertex.init(real_rect.x + real_rect.width - 1, real_rect.y + real_rect.height - 1, color).offset(1, 1).withUV(1, 1);

    try self.appendTriangles(texture, &[_][3]Vertex{
        .{ tl, br, tr },
        .{ br, tl, bl },
    });
}

/// Appends a rectangle with a 1 pixel wide outline
pub fn drawRectangle(self: *Self, rectangle: Rectangle, color: Color) DrawError!void {
    return self.drawRectanglePixels(self.scaleRectangle(rectangle), color);
}

pub fn drawRectanglePixels(self: *Self, real_rect: Rectangle, color: Color) DrawError!void {
    if (real_rect.size().isEmpty())
        return;

    const tl = Vertex.init(real_rect.x, real_rect.y, color);
    const tr = Vertex.init(real_rect.x + real_rect.width - 1, real_rect.y, color);
    const bl = Vertex.init(real_rect.x, real_rect.y + real_rect.height - 1, color);
    const br = Vertex.init(real_rect.x + real_rect.width - 1, real_rect.y + real_rect.height - 1, color);

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
pub fn drawLine(self: *Self, x0: i16, y0: i16, x1: i16, y1: i16, color: Color) DrawError!void {
    return self.drawLinePixels(
        self.scalePosition(x0),
        self.scalePosition(y0),
        self.scalePosition(x1),
        self.scalePosition(y1),
        color,
    );
}

pub fn drawLinePixels(self: *Self, x0: i16, y0: i16, x1: i16, y1: i16, color: Color) DrawError!void {
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

pub fn pushClipRectangle(self: *Self, rectangle: Rectangle) !void {
    const draw_call = try self.draw_calls.addOne();
    draw_call.* = DrawCall{
        .push_clip_rect = rectangle,
    };
}

pub fn popClipRectangle(self: *Self) !void {
    const draw_call = try self.draw_calls.addOne();
    draw_call.* = .pop_clip_rect;
}

pub fn setClipRectangle(self: *Self, rectangle: Rectangle) !void {
    const draw_call = try self.draw_calls.addOne();
    draw_call.* = DrawCall{
        .set_clip_rect = rectangle,
    };
}

pub fn clearClipRectangle(self: *Self) !void {
    const draw_call = try self.draw_calls.addOne();
    draw_call.* = .clear_clip_rect;
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

const DrawCall = union(enum) {
    draw_vertices: DrawVertices,
    push_clip_rect: Rectangle,
    pop_clip_rect,
    set_clip_rect: Rectangle,
    clear_clip_rect,
};

const DrawVertices = struct {
    offset: usize,
    count: usize,
    texture: ?*ResourceManager.Texture,
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

    /// size of the font without scaling
    font_size: u15,

    ascent: i16,
    descent: i16,
    line_gap: i16,

    pub fn getScale(self: Font) f32 {
        return c.stbtt_ScaleForPixelHeight(&self.font, @intToFloat(f32, self.font_size));
    }

    pub fn scaleValue(self: Font, v: i16) f32 {
        return @intToFloat(f32, v) * self.getScale();
    }

    /// Returns the height of a single text line of this font
    pub fn getLineHeight(self: Font) u15 {
        return @intCast(u15, scaleInt(self.ascent - self.descent + self.line_gap, self.getScale()));
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

    texture: *ResourceManager.Texture,

    fn getAlpha(self: Glyph, x: u15, y: u15) u8 {
        if (x >= self.width or y >= self.height)
            return 0;

        return self.pixels[@as(usize, std.math.absCast(y)) * self.width + @as(usize, std.math.absCast(x))];
    }
};

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
