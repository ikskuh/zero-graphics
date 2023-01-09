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

pub const Color: type = zg.Color;
pub const Point: type = zg.Point;
pub const Size: type = zg.Size;
pub const Rectangle: type = zg.Rectangle;
pub const MouseButton: type = zg.Input.MouseButton;
pub const KeyCode: type = zg.Input.Scancode;

pub const VerticalAlignment: type = zg.VerticalAlignment;
pub const HorizontalAlignment: type = zg.HorzizontalAlignment;

pub const KeyModifiers: type = zg.Input.Modifiers;

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

    std.debug.assert(@hasField(MouseButton, "primary"));
    std.debug.assert(@hasField(MouseButton, "secondary"));

    std.debug.assert(@hasField(VerticalAlignment, "top"));
    std.debug.assert(@hasField(VerticalAlignment, "center"));
    std.debug.assert(@hasField(VerticalAlignment, "bottom"));

    std.debug.assert(@hasField(HorizontalAlignment, "left"));
    std.debug.assert(@hasField(HorizontalAlignment, "center"));
    std.debug.assert(@hasField(HorizontalAlignment, "right"));

    std.debug.assert(@hasField(KeyModifiers, "ctrl"));
    std.debug.assert(@hasField(KeyModifiers, "alt"));
    std.debug.assert(@hasField(KeyModifiers, "shift"));
    std.debug.assert(@hasField(KeyModifiers, "gui"));
}
