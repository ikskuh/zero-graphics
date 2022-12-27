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

pub const Color = core_types.Color;
pub const Point = core_types.Point;
pub const Size = core_types.Size;
pub const Rectangle = core_types.Rectangle;
pub const MouseButton = core_types.MouseButton;
pub const KeyCode = core_types.KeyCode;
pub const VerticalAlignment = core_types.VerticalAlignment;
pub const HorizontalAlignment = core_types.HorizontalAlignment;

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

/// An abstract font that can is implemented by the rendering backend. The UI system itself
/// only stores a reference to the font, so anything can be stored in here.
pub const Font = struct {
    vtable: *const VTable,
    ptr: *anyopaque,

    pub const VTable = struct {
        getLineHeightFn: *const fn (*anyopaque) u15,
        measureStringFn: *const fn (*anyopaque, text: []const u8) u15,
    };

    pub fn getLineHeight(font: Font) u15 {
        return font.vtable.getLineHeightFn(font.ptr);
    }

    pub fn measureString(font: Font, string: []const u8) u15 {
        return font.vtable.measureStringFn(font.ptr, string);
    }
};

/// An abstract graphics object that is implemented by the rendering backend. The UI system itself
/// only stores a reference to the font, so anything can be stored in here.
///
/// This can either be a pixel graphic or a vector graphic, the file format support is up to the
/// rendering backend.
pub const Image = struct {
    vtable: *const VTable,
    ptr: *anyopaque,

    pub const VTable = struct {
        getSizeFn: *const fn (*anyopaque) Size,
    };

    pub fn getSize(image: Image) Size {
        return image.vtable.getSizeFn(image.ptr);
    }
};
