const std = @import("std");
const ui = @import("ui.zig");

const Point = ui.Point;
const MouseButton = ui.MouseButton;
const KeyCode = ui.KeyCode;

pub const InputEvent = union(enum) {
    mouse_button_down: MouseButton,
    mouse_button_up: MouseButton,
    mouse_motion: Point,

    key_down: KeyInfo,
    key_up: KeyInfo,

    text_input: []const u8,
};

pub const KeyInfo = struct {
    scancode: u16,
    key: KeyCode,
    modifiers: ui.KeyModifiers,
};
