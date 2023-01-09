const std = @import("std");
const ui = @import("ui");

const Button = @This();

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

pub fn sendInput(ctrl: *Button, widget: *ui.Widget, view: *ui.View, input: ui.Widget.Event) ui.Widget.InputHandling {
    switch (input) {
        .click => if (ctrl.on_click) |click_event_handler| {
            view.pushEvent(.{
                .sender = widget,
                .data = .none,
                .handler = click_event_handler,
            });
            return .ignore;
        },
        else => {},
    }
    return .process;
}
