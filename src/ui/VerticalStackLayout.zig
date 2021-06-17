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

pub fn get(self: *Self, height: u15) Rectangle {
    defer self.current_offset += height;
    return Rectangle{
        .x = self.base_rectangle.x,
        .y = self.base_rectangle.y + self.current_offset,
        .width = self.base_rectangle.width,
        .height = height,
    };
}

pub fn advance(self: *Self, margin: u15) void {
    _ = get(self, margin);
}
