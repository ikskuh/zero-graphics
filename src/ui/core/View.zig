//!
//! A `View` is a surface the user can see and interact with. Surfaces
//! display a widget hierarchy and are often implemented as windows, but can
//! also take up the whole screen or can be displayed inside a 3D world (AR).
//!
//! Views are the root component of every user interface and can be considered
//! an instance of that user interface.
//!

const std = @import("std");
const ui = @import("ui.zig");

const View = @This();
const Widget = ui.Widget;
const Event = ui.Event;
const InputEvent = ui.InputEvent;

/// The root widget of the view. If set, this widget will receive all events
/// and should be rendered to the user.
root: ?*Widget,

/// The currently focused widget.
focus: ?*Widget = null,

pub fn pushInput(view: *View, input: InputEvent) void {
    _ = view;
    _ = input;
}

pub fn pullEvent(view: *View) ?Event {
    //
    _ = view;
    return null;
}
