const std = @import("std");

pub const Point = struct {
    x: i16,
    y: i16,

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

    pub fn init(position: Point, size: Size) Rectangle {
        return Rectangle{
            .x = position.x,
            .y = position.y,
            .width = size.width,
            .height = size.height,
        };
    }

    pub fn contains(self: Rectangle, point: Point) bool {
        return point.x >= self.x and
            point.y >= self.y and
            point.x < self.x + self.width and
            point.y < self.y + self.height;
    }

    pub fn position(self: Rectangle) Point {
        return Point{ .x = self.y, .y = self.y };
    }

    pub fn size(self: Rectangle) Size {
        return Size{ .width = self.width, .height = self.height };
    }
};

pub const Size = struct {
    width: u15,
    height: u15,
};

pub const VerticalAlignment = enum { top, center, bottom };
pub const HorzizontalAlignment = enum { left, center, right };

pub const Color = extern struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 0xFF,

    // Support for std.json:

    pub fn jsonStringify(value: @This(), options: std.json.StringifyOptions, writer: anytype) !void {
        try writer.print("\"#{X:0>2}{X:0>2}{X:0>2}", .{ value.r, value.g, value.b });
        if (value.a != 0xFF) {
            try writer.print("{X:0>2}", .{value.a});
        }
        try writer.writeAll("\"");
    }

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

    // Predefined color values:
    pub const transparent = .{ .r = 0, .g = 0, .b = 0, .a = 0 };
    pub const black = Color{ .r = 0x00, .g = 0x00, .b = 0x00 };
    pub const white = Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF };
};
