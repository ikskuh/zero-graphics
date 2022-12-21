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
widgets: Widget.List,

/// The currently focused widget.
focus: ?*Widget = null,

/// Stores pending events emitted by widgets.
event_queue: ui.RingBuffer(Event, 64) = .{},

pub fn pushInput(view: *View, input: InputEvent) void {
    _ = view;
    _ = input;
}

pub fn pullEvent(view: *View) ?Event {
    return view.event_queue.pull();
}

pub fn init(view: *View, allocator: std.mem.Allocator) !void {
    try view.recursiveInit(view.widgets, allocator);
}

fn recursiveInit(view: *View, list: Widget.List, allocator: std.mem.Allocator) !void {
    var it = Widget.Iterator.init(list, .bottom_to_top);
    while (it.next()) |w| {
        try w.init(allocator);
        try view.recursiveInit(w.children);
    }
}

/// Releases the resources allocated by `Widget.init`.
///
/// **NOTE:** This function should not be called manually. Use `View.init` instead!
pub fn deinit(view: *View) void {
    view.recursiveDeinit(view.widgets);
}

fn recursiveDeinit(view: *View, list: Widget.List) !void {
    var it = Widget.Iterator.init(list, .bottom_to_top);
    while (it.next()) |w| {
        try w.deinit();
        try view.recursiveDeinit(w.children);
    }
}
