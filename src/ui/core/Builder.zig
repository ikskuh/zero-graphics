const std = @import("std");
const ui = @import("ui.zig");

const Builder = @This();
const Widget = ui.Widget;

fn MemoryPool(comptime T: type) type {}

pool: MemoryPool(Widget),

root: ?*Widget = null,
current: ?*Widget = null,

/// Starts the construction of a new widget hierarchy, will
/// allocate all widgets inside a memory pool.
pub fn begin(allocator: std.mem.Allocator) Builder {
    _ = allocator;
    return Builder{
        //
    };
}

/// Cancels the construction process and frees all memory.
/// The builder is unusable after this.
pub fn cancel(builder: *Builder) void {
    builder.* = undefined;
}

const OutValue = struct {
    memory: MemoryPool(Widget),
    view: ui.View,
};

/// Finalizes the construction of the widget tree and returns
/// the tree and a handle to the created memory.
/// The builder is unusable after this.
pub fn finish(builder: *Builder) OutValue {
    builder.* = undefined;
    @panic("nope");
}

//////////////////////////////////////

/// Returns a handle to the last added widget.
/// Asserts that a widget was already added.
pub fn current(builder: *Builder) *Widget {
    _ = builder;
    unreachable;
}

/// Returns a handle to the widget we currently
/// add children to.
/// Asserts that we've entered a widget.
pub fn parent(builder: *Builder) *Widget {
    _ = builder;
    unreachable;
}

/// Enters the current widget. The new widgets
/// created from now on will be added to the
/// `current` widget.
pub fn enter(builder: *Builder) void {
    _ = builder;
    unreachable;
}

/// Leaves the `parent()` widget. The new widgets
/// created from now on will be added as siblings
/// to `parent()`.
pub fn leave(builder: *Builder) void {
    _ = builder;
    unreachable;
}

/// Creates a new memory node, stores the passed widget
/// into it, then appends the widget to the current
/// tree level.
/// Returns a pointer to the memoized widget.
pub fn add(builder: *Builder, widget: Widget) !*Widget {
    _ = builder;
    _ = widget;
    unreachable;
}
