const std = @import("std");

const core_types = @import("core_types.zig");

pub const controls = @import("controls.zig");
pub const events = @import("events.zig");
pub const input = @import("input.zig");

pub const View = @import("View.zig");
pub const Widget = @import("Widget.zig");

pub const Event = events.Event;
pub const EventHandler = events.EventHandler;

pub const InputEvent = input.InputEvent;

pub const Point = core_types.Point;
pub const Size = core_types.Size;
pub const Rectangle = core_types.Rectangle;
pub const MouseButton = core_types.MouseButton;
pub const KeyCode = core_types.KeyCode;

pub const Builder = @import("Builder.zig");

pub const MemoryPool = @import("MemoryPool.zig").MemoryPool;
pub const RingBuffer = @import("RingBuffer.zig").RingBuffer;

pub const Visibility = enum {
    /// The item is fully visible
    visible,

    /// The item is visually not rendered and does not receive events,
    /// but will still take up space in the layout.
    hidden,

    /// The item is collapsed and will disappear entirely from the screen.
    /// Neither input, rendering nor layouting will see this node.
    collapsed,
};

/// A on-screen rectangle. It has a position and size, but also constraints
/// for the size, so a layout engine can use those to mutate position and size.
pub const LayoutedRectangle = struct {
    position: Point,
    size: Size,

    min_size: Size = Size.new(0, 0),
    max_size: Size = Size.new(std.math.maxInt(u15), std.math.maxInt(u15)),
};
