const std = @import("std");
const ui = @import("ui");

const CheckBox = @This();

on_checked_changed: ?ui.EventHandler = null,

font: ?ui.Font = null,
text: ?[]const u8 = null,

checked: bool,

pub fn canReceiveFocus(ctrl: CheckBox) bool {
    _ = ctrl;
    return true;
}

pub fn isHitTestVisible(ctrl: CheckBox) bool {
    _ = ctrl;
    return true;
}
