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
const logger = std.log.scoped(.@"ui.view");

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

/// The widget that currently is hovered by the mouse.
hovered_widget: ?*Widget = null,

/// Stores pending events emitted by widgets.
event_queue: ui.RingBuffer(Event, 64) = .{},

/// The currently clicked widget per mouse button
clicked_widgets: std.enums.EnumArray(MouseButton, ?*Widget) = std.enums.EnumArray(MouseButton, ?*Widget).initFill(null),

fn inputToWidgetEvent(input: InputEvent) Widget.Event {
    return switch (input) {
        .mouse_button_down => |v| .{ .mouse_button_down = v },
        .mouse_button_up => |v| .{ .mouse_button_up = v },
        .mouse_motion => |v| .{ .mouse_motion = v },
        .key_down => |v| .{ .key_down = v },
        .key_up => |v| .{ .key_up = v },
        .text_input => |v| .{ .text_input = v },
    };
}

pub fn pushInput(view: *View, input: InputEvent) void {
    switch (input) {
        .mouse_button_down => |button| {
            const clicked = view.widgetFromPosition(view.mouse_position);
            view.clicked_widgets.set(button, clicked);
            if (clicked) |widget| {
                _ = widget.sendInput(view, inputToWidgetEvent(input));
            }
        },

        .mouse_button_up => |button| {
            const clicked = view.widgetFromPosition(view.mouse_position);
            if (clicked) |widget| {
                _ = widget.sendInput(view, inputToWidgetEvent(input));

                if (button == .primary and view.clicked_widgets.get(button) == widget) {
                    if (widget.canReceiveFocus()) {
                        view.setFocus(widget);
                    }
                    _ = widget.sendInput(view, .click);
                }
            }
            view.clicked_widgets.set(button, null);
        },
        .mouse_motion => |position| {
            view.mouse_position = position;

            const hovered_widget = view.widgetFromPosition(view.mouse_position);

            if (hovered_widget != view.hovered_widget) {
                if (view.hovered_widget) |old| _ = old.sendInput(view, .mouse_leave);
                view.hovered_widget = hovered_widget;
                if (view.hovered_widget) |new| _ = new.sendInput(view, .mouse_enter);
            }

            if (hovered_widget) |widget| {
                // TODO: Translate coordinates to "local"
                _ = widget.sendInput(view, inputToWidgetEvent(input));
            }
        },
        .key_down => |key_info| {
            if (view.focus) |focused_widget| {
                if (focused_widget.sendInput(view, inputToWidgetEvent(input)) == .ignore)
                    return;
            }

            switch (key_info.key) {
                .tab => {
                    view.moveFocus(if (key_info.modifiers.shift) .previous else .next);
                },
                .space, .@"return", .keypad_enter => {
                    if (view.focus) |focused|
                        _ = focused.sendInput(view, .click);
                },
                else => {},
            }
        },
        .key_up => {
            if (view.focus) |focused_widget| {
                if (focused_widget.sendInput(view, inputToWidgetEvent(input)) == .ignore)
                    return;
            }
        },
        .text_input => {
            if (view.focus) |focused_widget| {
                if (focused_widget.sendInput(view, inputToWidgetEvent(input)) == .ignore)
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

pub fn pushEvent(view: *View, event: Event) void {
    if (view.event_queue.full()) {
        logger.warn("ui event queue full, dropping event...", .{});
    }
    view.event_queue.push(event);
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

fn updateParents(view: *View) void {
    view.updateParentsRecursive(view.widgets, null);
}

fn updateParentsRecursive(view: *View, list: Widget.List, parent: ?*Widget) void {
    var it = Widget.Iterator.init(list, .bottom_to_top);
    while (it.next()) |w| {
        w.parent = parent;
        view.updateParentsRecursive(w.children, w);
    }
}

const FocusSearchDir = enum { next, previous };

pub fn moveFocus(view: *View, dir: FocusSearchDir) void {
    view.setFocus(view.searchFocusWidget(view.focus, dir));
}

pub fn setFocus(view: *View, new_focus: ?*Widget) void {
    if (new_focus != view.focus) {
        if (view.focus) |old| _ = old.sendInput(view, .leave);
        view.focus = new_focus;
        if (view.focus) |new| _ = new.sendInput(view, .enter);
    }
}

fn searchFocusWidget(view: *View, widget: ?*Widget, dir: FocusSearchDir) ?*Widget {
    var iter = widget;

    while (true) {
        var next = view.searchFocusWidgetInner(iter, dir) orelse return null;
        if (next == widget)
            return widget;
        if (next.canReceiveFocus())
            return next;
        // Search forward
        iter = next;
    }
}

fn searchFocusWidgetInner(view: *View, widget: ?*Widget, dir: FocusSearchDir) ?*Widget {
    view.updateParents();

    if (widget) |w| {
        return switch (dir) {
            .next => if (w.children.first) |child|
                Widget.fromNode(child)
            else if (w.siblings.next) |next|
                Widget.fromNode(next)
            else
                Widget.fromOptNode(view.widgets.first),

            .previous => if (w.siblings.prev) |prev|
                Widget.fromNode(prev)
            else if (w.parent) |parent|
                parent
            else
                Widget.fromOptNode(findLastChild(view.widgets.last)),
        };
    } else {
        // search first or last widget
        return switch (dir) {
            .next => Widget.fromOptNode(view.widgets.first),
            .previous => Widget.fromOptNode(findLastChild(view.widgets.last)),
        };
    }
}

fn findLastChild(widget: ?*Widget.Node) ?*Widget.Node {
    const w = Widget.fromNode(widget orelse return null);
    if (w.children.len > 0)
        return findLastChild(w.children.last);
    return widget;
}
