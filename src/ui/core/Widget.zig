const std = @import("std");
const ui = @import("ui.zig");

const Widget = @This();

const List = std.TailQueue(Widget);
const Node = List.Node;

/// an intrusive linked list node that points to the previous and next sibling in the current context.
siblings: Node = .{ .data = .{} },

/// points to the first child.
children: ?*Node,

/// The actual behaviour of the widget. This defines how the control is rendered
/// and reacts to input.
control: ui.controls.Control,

fn nodeToWidget(node: *Node) *Widget {
    return @fieldParentPtr(Widget, "siblings", node);
}
