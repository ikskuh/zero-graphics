//!
//! Implementation of a single-line text editor
//!

const std = @import("std");
const TextEditor = @import("TextEditor");
const ui = @import("ui");
const TextBox = @This();
const logger = std.log.scoped(.TextBox);

const Flags = packed struct {
    password: bool = false,
    read_only: bool = false,
};

// public:
flags: Flags = .{},
editor: TextEditor = undefined,
font: ?ui.Font = null,

// private:

/// The scroll offset of the cursor. Shift of the text to the left.
/// Should be changed by the renderer to scroll the text view left/right on overflow.
scroll_offset: u15 = 0,

pub fn init(ctrl: *TextBox, allocator: std.mem.Allocator) !void {
    ctrl.editor = try TextEditor.init(allocator, "");
}

pub fn deinit(ctrl: *TextBox) void {
    ctrl.editor.deinit();
}

pub fn canReceiveFocus(ctrl: *TextBox) bool {
    _ = ctrl;
    return true;
}

pub fn isHitTestVisible(ctrl: *TextBox) bool {
    _ = ctrl;
    return true;
}

pub fn setText(ctrl: *TextBox, string: []const u8) !void {
    try ctrl.editor.setText(string);
}

pub fn getText(ctrl: TextBox) []const u8 {
    return ctrl.editor.getText();
}

pub fn getCursor(ctrl: TextBox) usize {
    return ctrl.editor.cursor;
}

pub fn sendInput(ctrl: *TextBox, widget: *ui.Widget, view: *ui.View, input: ui.Widget.Event) ui.Widget.InputHandling {
    _ = widget;
    _ = view;

    switch (input) {
        .mouse_button_down,
        .mouse_button_up,
        .mouse_motion,
        .mouse_enter,
        .mouse_leave,
        .click,
        .enter,
        .leave,
        => return .ignore,

        .key_down => |key_info| switch (key_info.key) {
            .left => ctrl.editor.moveCursor(.left, if (key_info.modifiers.ctrl)
                .word
            else
                .letter),
            .right => ctrl.editor.moveCursor(.right, if (key_info.modifiers.ctrl)
                .word
            else
                .letter),

            .home => ctrl.editor.moveCursor(.left, .line),
            .end => ctrl.editor.moveCursor(.right, .line),

            .backspace => ctrl.editor.delete(.left, if (key_info.modifiers.ctrl)
                .word
            else
                .letter),

            .delete => ctrl.editor.delete(.right, if (key_info.modifiers.ctrl)
                .word
            else
                .letter),

            else => return .process,
        },

        .key_up => return .process,

        .text_input => |text| {
            ctrl.editor.insertText(text) catch |err| logger.err("Could not insert text: {s}", .{@errorName(err)});
        },
    }

    return .ignore;
}

pub const Modifiers = struct {
    shift: bool = false,
    ctrl: bool = false,
    alt: bool = false,
    super: bool = false,
};
