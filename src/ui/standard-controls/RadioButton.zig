const std = @import("std");
const ui = @import("ui");

const RadioButton = @This();

/// A radio group stores which of several radio buttons is
/// selected.
/// This is done by using a common `selection` index, and
/// each radio button has a property `selector` that defines
/// on which index the button is considered *active*.
pub const RadioGroup = struct {
    selection: u32,

    /// Is triggered, when a button changes the
    /// active selection.
    on_selection_changed: ?ui.EventHandler = null,
};

on_click: ?ui.EventHandler = null,

font: ?ui.Font = null,
text: ?[]const u8 = null,

group: *RadioGroup,

/// Determines on which `group.selection` value the button
/// is active.
selector: u32,

pub fn canReceiveFocus(ctrl: RadioButton) bool {
    _ = ctrl;
    return true;
}

pub fn isHitTestVisible(ctrl: RadioButton) bool {
    _ = ctrl;
    return true;
}
