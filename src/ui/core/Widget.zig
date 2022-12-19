const std = @import("std");
const ui = @import("ui.zig");

const Widget = @This();

pub const List = std.TailQueue(void);
pub const Node = List.Node;

/// an intrusive linked list node that points to the previous and next sibling in the current context.
siblings: Node = .{ .data = {} },

/// points to the first child.
children: List = .{},

/// The actual behaviour of the widget. This defines how the control is rendered
/// and reacts to input.
control: ui.controls.Control,

pub fn fromNode(node: *Node) *Widget {
    return @fieldParentPtr(Widget, "siblings", node);
}
