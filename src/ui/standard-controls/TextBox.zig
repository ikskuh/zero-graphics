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

flags: Flags = .{},
editor: TextEditor = undefined,
font: ?ui.Font = null,

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

pub fn getText(ctrl: TextBox) []const u8 {
    return ctrl.editor.getText();
}

pub fn getCursor(ctrl: TextBox) usize {
    return ctrl.editor.getCursor();
}

pub fn sendInput(ctrl: *TextBox, widget: *ui.Widget, view: *ui.View, input: ui.InputEvent) ui.Widget.InputHandling {
    var modifiers = Modifiers{};

    // TODO: Compute modifiers

    //
    _ = widget;
    _ = view;

    switch (input) {
        .mouse_button_down, .mouse_button_up, .mouse_motion => {}, // ignore event
        .key_down => |key_info| switch (key_info.key) {
            .left => ctrl.editor.moveCursor(.left, if (modifiers.ctrl)
                .word
            else
                .letter),
            .right => ctrl.editor.moveCursor(.right, if (modifiers.ctrl)
                .word
            else
                .letter),

            .home => ctrl.editor.moveCursor(.left, .line),
            .end => ctrl.editor.moveCursor(.right, .line),

            .backspace => ctrl.editor.delete(.left, if (modifiers.ctrl)
                .word
            else
                .letter),
            .delete => ctrl.editor.delete(.right, if (modifiers.ctrl)
                .word
            else
                .letter),

            else => {},
        },
        .key_up => {},
        .text_input => |text| {
            ctrl.editor.insertText(text) catch |err| logger.err("Could not insert text: {s}", .{@errorName(err)});
        },
    }

    return .process;
}

pub const Modifiers = struct {
    shift: bool = false,
    ctrl: bool = false,
    alt: bool = false,
    super: bool = false,
};
