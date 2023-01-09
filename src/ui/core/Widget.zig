const std = @import("std");
const ui = @import("ui.zig");
const logger = std.log.scoped(.ui_widget);

const Widget = @This();
const InputEvent = ui.InputEvent;
const View = ui.View;

pub const List = std.TailQueue(void);
pub const Node = List.Node;

/// An intrusive linked list node that points to the previous and next sibling in the current context.
/// This item is embedded in either `Widget.children` or `View.widgets`.
siblings: Node = .{ .data = {} },

/// The list of children this node has. Is stored bottom-to-top, so the first
/// item in the list is the bottom-most, the last item is the top-most.
children: List = .{},

/// Pointer to the parent widget, if any.
/// All non-top-level widgets have a parent widget that is lazily updated by the UI
/// when its needed.
parent: ?*Widget = null,

/// The actual behaviour of the widget. This defines how the control is rendered
/// and reacts to input.
control: ui.controls.Control,

/// The boundaries of the widget inside its parent. If the widget is a top-level widget, it
/// determines the position of the widget inside the view.
/// Pass a pointer to this rectangle into a layout engine to enable layouting for this widget.
bounds: ui.LayoutedRectangle = .{
    .position = ui.Point.new(0, 0),
    .size = ui.Size.new(32, 32),
},

/// If a widget is enabled, it is able to receive events from the user. Otherwise,
/// it might be rendered disabled.
enabled: bool = true,

/// If the widget is visible for the hit test, it can be selected with the mouse.
/// This is usually enabled, but it's sometimes useful to create overlays over certain
/// parts of the UI that should not interact with the user.
hit_test_visible: bool = true,

/// The widget can be focused with either the mouse or the keyboard. If this is disabled,
/// the user won't be able to interact with this widget via the keyboard.
///
/// **NOTE:** Even if this is set to `true`, a control might be non-focusable in the first place,
///           so to query this property, it's adviced to use the `Widget.canReceiveFocus()` function.
can_receive_focus: bool = true,

/// The visibility of this node. Control how it is visible.
visibility: ui.Visibility = .visible,

/// Converts a `node` from a widget list back into a `Widget`.
pub fn fromNode(node: *Node) *Widget {
    return @fieldParentPtr(Widget, "siblings", node);
}

/// Converts an optional `node` from a widget list back into an optional `Widget`.
pub fn fromOptNode(node: ?*Node) ?*Widget {
    return if (node) |n| fromNode(n) else null;
}

/// Initializes the widget and its control. Will allocate dynamic resources
/// and create structures that are required for operating the widget.
///
/// **NOTE:** This function should not be called manually. Use `View.init` instead!
pub fn init(widget: *Widget, allocator: std.mem.Allocator) !void {
    try ui.controls.init(&widget.control, allocator);
}

/// Releases the resources allocated by `Widget.init`.
///
/// **NOTE:** This function should not be called manually. Use `View.init` instead!
pub fn deinit(widget: *Widget) void {
    ui.controls.deinit(&widget.control);
}

/// Returns true when this widget can be focused with the mouse or keyboard (by using the Tab key).
pub fn canReceiveFocus(widget: *Widget) bool {
    return widget.can_receive_focus and ui.controls.canReceiveFocus(&widget.control);
}

/// Returns true when this widget can be focused with the mouse or keyboard (by using the Tab key).
pub fn isHitTestVisible(widget: *Widget) bool {
    return widget.hit_test_visible and ui.controls.isHitTestVisible(&widget.control);
}

pub const InputHandling = enum {
    /// The ui system should ignore the event, it was already handled
    /// by a previous part of the event chain.
    ignore,

    /// The ui system should process the event, it might already be
    /// handled by previous parts of the event chain, but the event
    /// was not swallowed.
    process,
};

pub const Event = union(enum) {
    // mouse events:
    mouse_enter, // mouse entered the widget area
    mouse_leave, // mouse left the widget area
    mouse_button_down: ui.MouseButton, // mouse button was pressed
    mouse_button_up: ui.MouseButton, // mouse button was released
    mouse_motion: ui.Point, // mouse moved to a different position

    // keyboard events:
    key_down: ui.input.KeyInfo, // a key was pressed
    key_up: ui.input.KeyInfo, // a key was released
    text_input: []const u8, // some text was entered

    // meta events:
    enter, // widget gets focus
    leave, // widget looses focus
    click, // user clicked the widget with mouse, touch or pressed space or return
};

pub fn sendInput(widget: *Widget, view: *View, event: Event) InputHandling {
    logger.debug("{s} received event {s}", .{ @tagName(widget.control), @tagName(event) });

    if (ui.controls.sendInput(&widget.control, widget, view, event) == .ignore)
        return .ignore;

    return .process;
}

pub const IterationDirection = enum {
    bottom_to_top,
    top_to_bottom,
};
pub const Iterator = struct {
    node: ?*Node,
    dir: IterationDirection,

    pub fn init(list: List, dir: IterationDirection) Iterator {
        return Iterator{
            .node = switch (dir) {
                .bottom_to_top => list.first,
                .top_to_bottom => list.last,
            },
            .dir = dir,
        };
    }

    pub fn next(iter: *Iterator) ?*Widget {
        const current = iter.node orelse return null;
        iter.node = switch (iter.dir) {
            .bottom_to_top => current.next,
            .top_to_bottom => current.prev,
        };
        return fromNode(current);
    }
};

/// Moves the widget on the screen, relative to its parent.
/// **NOTE:** If a layout engine is used, it might override the values set here.
pub fn setPosition(widget: *Widget, pos: ui.Point) void {
    widget.bounds.position = pos;
}

/// Resizes the widget, respecting size constraints.
/// **NOTE:** If a layout engine is used, it might override the values set here.
pub fn setSize(widget: *Widget, size: ui.Size) void {
    widget.bounds.size = ui.Size.new(
        std.math.clamp(size.width, widget.bounds.min_size.width, widget.bounds.max_size.width),
        std.math.clamp(size.height, widget.bounds.min_size.height, widget.bounds.max_size.height),
    );
}

/// Sets the position and size of the widget, respecting size constraints.
/// The rectangles position is relative to its parent.
/// **NOTE:** If a layout engine is used, it might override the values set here.
pub fn setBounds(widget: *Widget, rectangle: ui.Rectangle) void {
    widget.setPosition(rectangle.position());
    widget.setSize(rectangle.size());
}

/// Returns the rectangle this widget occupies in its parent.
pub fn getBounds(widget: Widget) ui.Rectangle {
    return ui.Rectangle.new(widget.bounds.position, widget.bounds.size);
}
