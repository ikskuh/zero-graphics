pub const Point = struct {
    x: i16,
    y: i16,
};

pub const Rectangle = struct {
    x: i16,
    y: i16,
    width: u15,
    height: u15,
};

pub const Size = struct {
    width: u15,
    height: u15,
};

pub const VerticalAlignment = enum { top, center, bottom };
pub const HorzizontalAlignment = enum { left, center, right };
