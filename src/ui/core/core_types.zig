//! This file is meant to export some core types that might be provided by the surrounding
//! environment.
//!
//! The default implementation is using the regular zero-graphics types, but those can be replaced
//! by whatever types the user of this library things is appropiate.
//!
//! There are some comptime checks installed that make sure that the types meet the requirements.
//!

const std = @import("std");
const zg = @import("zero-graphics");

pub const Point: type = zg.Point;
pub const Size: type = zg.Size;
pub const Rectangle: type = zg.Rectangle;
pub const MouseButton: type = zg.MouseButton;
pub const KeyCode: type = zg.KeyCode;

comptime {
    std.debug.assert(@hasField(Point, "x"));
    std.debug.assert(@hasField(Point, "y"));

    std.debug.assert(@hasField(Size, "width"));
    std.debug.assert(@hasField(Size, "height"));

    std.debug.assert(@hasField(Rectangle, "x"));
    std.debug.assert(@hasField(Rectangle, "y"));
    std.debug.assert(@hasField(Rectangle, "width"));
    std.debug.assert(@hasField(Rectangle, "height"));

    std.debug.assert(@hasField(KeyCode, "escape"));
    std.debug.assert(@hasField(KeyCode, "tab"));
    std.debug.assert(@hasField(KeyCode, "space"));
    std.debug.assert(@hasField(KeyCode, "return"));

    std.debug.assert(@hasField(MouseButton, "left"));
    std.debug.assert(@hasField(MouseButton, "right"));
}
