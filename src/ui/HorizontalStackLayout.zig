const std = @import("std");
const types = @import("../types.zig");

const Rectangle = types.Rectangle;

const Self = @This();

base_rectangle: Rectangle,
current_offset: u15,

pub fn init(base: Rectangle) Self {
    return Self{
        .base_rectangle = base,
        .current_offset = 0,
    };
}

pub fn get(self: *Self, width: u15) Rectangle {
    defer self.current_offset += width;
    return Rectangle{
        .x = self.base_rectangle.x + self.current_offset,
        .y = self.base_rectangle.y,
        .width = width,
        .height = self.base_rectangle.height,
    };
}

pub fn adavance(self: *Self, margin: u15) void {
    _ = get(self, margin);
}
