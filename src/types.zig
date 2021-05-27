pub const Point = struct {
    x: i16,
    y: i16,
};

pub const Rectangle = struct {
    x: i16,
    y: i16,
    width: u15,
    height: u15,

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

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 0xFF,

    pub const black = Color{ .r = 0x00, .g = 0x00, .b = 0x00 };
    pub const white = Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF };
};
