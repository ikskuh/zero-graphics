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
const Point = ui.Point;
const MouseButton = ui.MouseButton;

/// The last known position of the mouse.
mouse_position: Point = Point.new(std.math.minInt(i16), std.math.minInt(i16)),

/// The root widget of the view. If set, this widget will receive all events
/// and should be rendered to the user.
widgets: Widget.List,

/// The currently focused widget.
focus: ?*Widget = null,

/// Stores pending events emitted by widgets.
event_queue: ui.RingBuffer(Event, 64) = .{},

/// The currently clicked widget per mouse button
clicked_widgets: std.enums.EnumArray(MouseButton, ?*Widget) = std.enums.EnumArray(MouseButton, ?*Widget).initFill(null),

pub fn pushInput(view: *View, input: InputEvent) void {
    switch (input) {
        .mouse_button_down => |button| {
            const clicked = view.widgetFromPosition(view.mouse_position);
            view.clicked_widgets.set(button, clicked);
            if (clicked) |widget| {
                // handle mouse down
                _ = widget;
            }
        },
        .mouse_button_up => |button| {
            const clicked = view.widgetFromPosition(view.mouse_position);
            if (clicked) |widget| {
                if (view.clicked_widgets.get(button) == widget) {
                    if (widget.canReceiveFocus()) {
                        view.focus = widget;
                    }

                    std.log.err("handle clicked for widget {s}", .{@tagName(widget.control)});
                }
            }
            view.clicked_widgets.set(button, null);
        },
        .mouse_motion => |position| {
            view.mouse_position = position;
            if (view.widgetFromPosition(view.mouse_position)) |widget| {
                //
                _ = widget;
            }
        },
        .key_down => |key_info| {
            if (view.focus) |focused_widget| {
                if (focused_widget.sendInput(view, input) == .ignore)
                    return;
            }

            switch (key_info.key) {
                .tab => {
                    // TODO: Move focus
                },
                .space, .@"return", .keypad_enter => {
                    // TODO: Send click
                },
                else => {},
            }
        },
        .key_up => {
            if (view.focus) |focused_widget| {
                if (focused_widget.sendInput(view, input) == .ignore)
                    return;
            }
        },
        .text_input => {
            if (view.focus) |focused_widget| {
                if (focused_widget.sendInput(view, input) == .ignore)
                    return;
            }
        },
    }
}

fn widgetFromPosition(view: *View, point: Point) ?*Widget {
    return view.recursiveWidgetFromPosition(view.widgets, point);
}

fn recursiveWidgetFromPosition(view: *View, list: Widget.List, point: Point) ?*Widget {
    var iter = Widget.Iterator.init(list, .top_to_bottom);
    while (iter.next()) |widget| {
        if (!widget.isHitTestVisible())
            continue;

        const bounds = widget.getBounds();
        if (!bounds.contains(point))
            continue;

        const client_point = Point.new(
            point.x - bounds.x,
            point.y - bounds.y,
        );

        if (view.recursiveWidgetFromPosition(widget.children, client_point)) |child|
            return child;

        return widget;
    }
    return null;
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
        try view.recursiveInit(w.children, allocator);
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
