const std = @import("std");
const ui = @import("ui");

on_click: ?ui.EventHandler = null,

font: ?ui.Font = null,
text: ?[]const u8 = null,

pub fn canReceiveFocus(ctrl: *@This()) bool {
    _ = ctrl;
    return true;
}

pub fn isHitTestVisible(ctrl: *@This()) bool {
    _ = ctrl;
    return true;
}
