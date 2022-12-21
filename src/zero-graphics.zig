const std = @import("std");

pub const loadOpenGlFunction = @import("root").loadOpenGlFunction;
pub const milliTimestamp = @import("root").milliTimestamp;
pub const getDisplayDPI = @import("root").getDisplayDPI;
pub const CoreApplication = @import("CoreApplication.zig");
pub const Application = @import("root").Application;

// opengl docs can be found here:
// https://www.khronos.org/registry/OpenGL-Refpages/es2.0/
pub const gles = @import("gl_es_2v0.zig");

pub const gles_utils = @import("rendering/gles-helper.zig");

pub const Renderer2D = @import("rendering/Renderer2D.zig");
pub const Renderer3D = @import("rendering/Renderer3D.zig");
pub const RendererSky = @import("rendering/RendererSky.zig");
pub const DebugRenderer3D = @import("rendering/DebugRenderer3D.zig");
pub const ResourceManager = @import("rendering/ResourceManager.zig");

pub const Input = @import("Input.zig");

pub usingnamespace if (build_options.features.code_editor) struct {
    pub const CodeEditor = @import("scintilla/CodeEditor.zig");
} else struct {};

pub const UserInterface = @import("UserInterface.zig");
pub const Editor = @import("Editor.zig");

pub const Backend = union(enum) {
    android,
    wasm,
    desktop,
};

pub const build_options = @import("root").build_options;

pub const backend: Backend = @import("root").backend;

pub const WebSocket = @import("root").WebSocket;

pub const Point = struct {
    pub const zero = Point{ .x = 0, .y = 0 };

    x: i16,
    y: i16,

    pub fn new(x: i16, y: i16) Point {
        return Point{ .x = x, .y = y };
    }

    pub fn add(a: Point, b: Point) Point {
        return new(a.x + b.x, a.y + b.y);
    }

    pub fn distance(a: Point, b: Point) u16 {
        return std.math.sqrt(distance2(a, b));
    }

    pub fn distance2(a: Point, b: Point) u32 {
        const dx = @as(u32, std.math.absCast(a.x - b.x));
        const dy = @as(u32, std.math.absCast(a.x - b.x));
        return dx * dx + dy * dy;
    }
};

pub const Rectangle = struct {
    x: i16,
    y: i16,
    width: u15,
    height: u15,

    pub fn left(r: Rectangle) i16 {
        return r.x;
    }
    pub fn right(r: Rectangle) i16 {
        return r.x + r.width - 1;
    }
    pub fn top(r: Rectangle) i16 {
        return r.y;
    }
    pub fn bottom(r: Rectangle) i16 {
        return r.y + r.height - 1;
    }

    pub fn new(pos: Point, siz: Size) Rectangle {
        return Rectangle{
            .x = pos.x,
            .y = pos.y,
            .width = siz.width,
            .height = siz.height,
        };
    }

    pub fn contains(self: Rectangle, point: Point) bool {
        return point.x >= self.x and
            point.y >= self.y and
            point.x < self.x + self.width and
            point.y < self.y + self.height;
    }

    pub fn position(self: Rectangle) Point {
        return Point{ .x = self.x, .y = self.y };
    }

    pub fn size(self: Rectangle) Size {
        return Size{ .width = self.width, .height = self.height };
    }

    pub fn shrink(self: Rectangle, delta: u15) Rectangle {
        return self.shrinkOrGrow(-@as(i16, delta));
    }

    pub fn grow(self: Rectangle, delta: u15) Rectangle {
        return self.shrinkOrGrow(@as(i16, delta));
    }

    pub fn shrinkOrGrow(self: Rectangle, delta: i16) Rectangle {
        return Rectangle{
            .x = self.x - delta,
            .y = self.y - delta,
            .width = @intCast(u15, if (self.width > 2 * delta) @as(i16, self.width) + 2 * delta else 0),
            .height = @intCast(u15, if (self.height > 2 * delta) @as(i16, self.height) + 2 * delta else 0),
        };
    }

    /// Returns a new rectangle with size (`width`,`height`) that will be centered over this
    /// rectangle.
    pub fn centered(self: Rectangle, width: u15, height: u15) Rectangle {
        return Rectangle{
            .x = self.x + @divTrunc((@as(i16, self.width) - width), 2),
            .y = self.y + @divTrunc((@as(i16, self.height) - height), 2),
            .width = width,
            .height = height,
        };
    }

    /// Returnst the area of the rectangle.
    pub fn area(self: Rectangle) u32 {
        return @as(u32, self.width) * @as(u32, self.height);
    }
};

pub const Size = struct {
    pub const empty = Size{ .width = 0, .height = 0 };

    width: u15,
    height: u15,

    pub fn new(w: u15, h: u15) Size {
        return Size{ .width = w, .height = h };
    }

    pub fn isEmpty(self: Size) bool {
        return (self.width == 0) or (self.height == 0);
    }

    pub fn getArea(self: Size) u30 {
        return @as(u30, self.width) * @as(u30, self.height);
    }
};

pub const VerticalAlignment = enum { top, center, bottom };
pub const HorzizontalAlignment = enum { left, center, right };

pub const colors = struct {
    pub const xkcd = @import("colors/xkcd.zig");
    pub const css3 = @import("colors/css3.zig");
};

pub const Color = extern struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 0xFF,

    pub fn rgb(r: u8, g: u8, b: u8) Color {
        return rgba(r, g, b, 0xFF);
    }

    pub fn rgba(r: u8, g: u8, b: u8, a: u8) Color {
        return Color{ .r = r, .g = g, .b = b, .a = a };
    }

    pub fn gray(level: u8) Color {
        return Color{ .r = level, .g = level, .b = level, .a = 0xFF };
    }

    pub fn rgb_f32(r: f32, g: f32, b: f32) Color {
        return rgba_f32(r, g, b, 1.0);
    }

    pub fn rgba_f32(r: f32, g: f32, b: f32, a: f32) Color {
        return Color{
            .r = clamp_to_u8(r),
            .g = clamp_to_u8(g),
            .b = clamp_to_u8(b),
            .a = clamp_to_u8(a),
        };
    }

    pub fn gray_f32(level: f32) Color {
        return rgb_f32(level, level, level);
    }

    fn clamp_to_u8(v: f32) u8 {
        return @floatToInt(u8, std.math.clamp(std.math.maxInt(u8) * v, 0.0, 255.0));
    }

    pub fn redf(c: Color) f32 {
        return @intToFloat(f32, c.r) / 255.0;
    }

    pub fn greenf(c: Color) f32 {
        return @intToFloat(f32, c.g) / 255.0;
    }

    pub fn bluef(c: Color) f32 {
        return @intToFloat(f32, c.b) / 255.0;
    }

    pub fn alphaf(c: Color) f32 {
        return @intToFloat(f32, c.a) / 255.0;
    }

    pub fn brightness(c: Color) u8 {
        return clamp_to_u8(c.brightnessf());
    }

    pub fn brightnessf(c: Color) f32 {
        // https://en.wikipedia.org/wiki/Relative_luminance
        return std.math.clamp(0.2126 * c.redf() + 0.7152 * c.greenf() + 0.0722 * c.bluef(), 0.0, 1.0);
    }

    // Support for std.json:

    // pub fn jsonStringify(value: @This(), options: std.json.StringifyOptions, writer: anytype) !void {
    //     try writer.print("\"#{X:0>2}{X:0>2}{X:0>2}", .{ value.r, value.g, value.b });
    //     if (value.a != 0xFF) {
    //         try writer.print("{X:0>2}", .{value.a});
    //     }
    //     try writer.writeAll("\"");
    // }

    pub fn alphaBlend(c0: Color, c1: Color, alpha: u8) Color {
        return alphaBlendF(c0, c1, @intToFloat(f32, alpha) / 255.0);
    }

    pub fn alphaBlendF(c0: Color, c1: Color, alpha: f32) Color {
        const f = std.math.clamp(alpha, 0.0, 1.0);
        return Color{
            .r = lerp(c0.r, c1.r, f),
            .g = lerp(c0.g, c1.g, f),
            .b = lerp(c0.b, c1.b, f),
            .a = lerp(c0.a, c1.a, f),
        };
    }

    fn lerp(a: u8, b: u8, f: f32) u8 {
        return @floatToInt(u8, @intToFloat(f32, a) + f * (@intToFloat(f32, b) - @intToFloat(f32, a)));
    }

    pub fn withAlpha(color: Color, alpha: u8) Color {
        var dupe = color;
        dupe.a = alpha;
        return dupe;
    }

    pub fn parse(string: []const u8) !Color {
        if (fromName(string)) |c| return c;

        if (std.mem.startsWith(u8, string, "#")) {
            // html color
            return try fromHtml(string);
        }

        return try fromValues(string, .int);
    }

    pub const ValueRange = enum { float, int };

    fn mapFloatToInt(a: f32) !u8 {
        if (a < 0.0) return error.Overflow;
        if (a > 1.0) return error.Overflow;
        return @floatToInt(u8, 255.0 * a);
    }

    /// Parses values that are written in 3-tuples or 4-tuples separated by comma, semicolon, space and tab.
    /// Examples:
    /// - `255,0,0`
    /// - `255;255;0`
    /// - `0.0 1.0 0.0`
    /// - `0.0; 1.0; 0.46`
    pub fn fromValues(string: []const u8, range: ValueRange) !Color {
        var tokenizer = std.mem.tokenize(u8, string, ",; \t");

        var r_str: []const u8 = tokenizer.next() orelse return error.InvalidFormat;
        var g_str: []const u8 = tokenizer.next() orelse return error.InvalidFormat;
        var b_str: []const u8 = tokenizer.next() orelse return error.InvalidFormat;
        var a_str: ?[]const u8 = tokenizer.next();
        if (tokenizer.next() != null)
            return error.InvalidFormat;

        return switch (range) {
            .float => Color{
                .r = try mapFloatToInt(try std.fmt.parseFloat(f32, r_str)),
                .g = try mapFloatToInt(try std.fmt.parseFloat(f32, g_str)),
                .b = try mapFloatToInt(try std.fmt.parseFloat(f32, b_str)),
                .a = try mapFloatToInt(try std.fmt.parseFloat(f32, a_str orelse "1.0")),
            },
            .int => Color{
                .r = try std.fmt.parseInt(u8, r_str, 0),
                .g = try std.fmt.parseInt(u8, g_str, 0),
                .b = try std.fmt.parseInt(u8, b_str, 0),
                .a = try std.fmt.parseInt(u8, a_str orelse "0xFF", 0),
            },
        };
    }

    fn expand4to8(c: u4) u8 {
        return (@as(u8, c) << 4) | c;
    }

    /// Parses one of the following patterns:
    /// - `#RGB`
    /// - `#RGBA`
    /// - `#RRGGBB`
    /// - `#RRGGBBAA`
    pub fn fromHtml(str: []const u8) !Color {
        if (str.len < 4) // requires at least #RGB
            return error.InvalidFormat;
        if (str[0] != '#') // must start with #
            return error.InvalidFormat;
        const hexchars = str[1..];

        var color = Color{ .r = 0, .g = 0, .b = 0, .a = 0xFF };

        if (hexchars.len == 3 or hexchars.len == 4) {
            // #RGB
            // #RGBA
            color.r = expand4to8(try std.fmt.parseInt(u4, hexchars[0..1], 16));
            color.g = expand4to8(try std.fmt.parseInt(u4, hexchars[1..2], 16));
            color.b = expand4to8(try std.fmt.parseInt(u4, hexchars[2..3], 16));
        } else if (hexchars.len == 6 or hexchars.len == 8) {
            // #RRGGBB
            // #RRGGBBAA
            color.r = try std.fmt.parseInt(u8, hexchars[0..2], 16);
            color.g = try std.fmt.parseInt(u8, hexchars[2..4], 16);
            color.b = try std.fmt.parseInt(u8, hexchars[4..6], 16);
        } else {
            return error.InvalidFormat;
        }

        if (hexchars.len == 4) {
            // #RGBA
            color.a = expand4to8(try std.fmt.parseInt(u4, hexchars[3..4], 16));
        } else if (hexchars.len == 8) {
            // #RRGGBBAA
            color.a = try std.fmt.parseInt(u8, hexchars[6..8], 16);
        } else {
            color.a = 0xFF;
        }

        return color;
    }

    /// Creates a color from one of the CSS3 named ones.
    pub fn fromName(name: []const u8) ?Color {
        inline for (comptime std.meta.declarations(colors.css3)) |decl| {
            if (!decl.is_pub)
                continue;
            if (std.ascii.eqlIgnoreCase(decl.name, name))
                return @field(colors.css3, decl.name);
        }
        return null;
    }

    // Predefined color values:
    pub const transparent = .{ .r = 0, .g = 0, .b = 0, .a = 0 };
    pub const black = Color{ .r = 0x00, .g = 0x00, .b = 0x00 };
    pub const white = Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF };
    pub const red = Color{ .r = 0xFF, .g = 0x00, .b = 0x00 };
    pub const lime = Color{ .r = 0x00, .g = 0xFF, .b = 0x00 };
    pub const blue = Color{ .r = 0x00, .g = 0x00, .b = 0xFF };
    pub const magenta = Color{ .r = 0xFF, .g = 0x00, .b = 0xFF };
    pub const yellow = Color{ .r = 0xFF, .g = 0xFF, .b = 0x00 };
    pub const cyan = Color{ .r = 0x00, .g = 0xFF, .b = 0xFF };
};

pub const FileFilter = struct {
    pattern: []const u8,
    title: ?[]const u8,
};

pub fn openFileDialog(allocator: std.mem.Allocator, filters: []const FileFilter, default_path: ?[]const u8) error{OutOfMemory}!?[]const u8 {
    _ = allocator;
    _ = filters;
    _ = default_path;
    return null;
}

pub fn saveFileDialog(allocator: std.mem.Allocator, filters: []const FileFilter, default_path: ?[]const u8) error{OutOfMemory}!?[]const u8 {
    _ = allocator;
    _ = filters;
    _ = default_path;
    return null;
}

pub fn openFolderDialog(allocator: std.mem.Allocator, default_path: ?[]const u8) error{OutOfMemory}!?[]const u8 {
    _ = allocator;
    _ = default_path;
    return null;
}
