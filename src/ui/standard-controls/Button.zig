const std = @import("std");
const ui = @import("ui");

on_click: ?ui.EventHandler = null,
text: []const u8,

pub fn canReceiveFocus(ctrl: *@This()) bool {
    _ = ctrl;
    return true;
}
