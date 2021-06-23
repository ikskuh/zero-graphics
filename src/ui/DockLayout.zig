const std = @import("std");
const types = @import("../common.zig");

const Rectangle = types.Rectangle;

const Self = @This();

pub const DockSite = enum {
    top,
    left,
    bottom,
    right,
};

rest_rectangle: Rectangle,

pub fn init(base: Rectangle) Self {
    return Self{
        .rest_rectangle = base,
    };
}

pub fn get(self: *Self, site: DockSite, size: u15) Rectangle {
    switch (site) {
        .top => {
            const result = Rectangle{
                .x = self.rest_rectangle.x,
                .y = self.rest_rectangle.y,
                .width = self.rest_rectangle.width,
                .height = size,
            };
            self.rest_rectangle.y += size;
            self.rest_rectangle.height -= size;
            return result;
        },
        .left => {
            const result = Rectangle{
                .x = self.rest_rectangle.x,
                .y = self.rest_rectangle.y,
                .width = size,
                .height = self.rest_rectangle.height,
            };
            self.rest_rectangle.x += size;
            self.rest_rectangle.width -= size;
            return result;
        },
        .bottom => {
            self.rest_rectangle.height -= size;
            const result = Rectangle{
                .x = self.rest_rectangle.x,
                .y = self.rest_rectangle.y + self.rest_rectangle.height,
                .width = self.rest_rectangle.width,
                .height = size,
            };
            return result;
        },
        .right => {
            self.rest_rectangle.width -= size;
            const result = Rectangle{
                .x = self.rest_rectangle.x + self.rest_rectangle.width,
                .y = self.rest_rectangle.y,
                .width = size,
                .height = self.rest_rectangle.height,
            };
            return result;
        },
    }
}

pub fn getRest(self: Self) Rectangle {
    return self.rest_rectangle;
}
