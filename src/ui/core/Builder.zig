const std = @import("std");
const ui = @import("ui.zig");

const Builder = @This();
const Widget = ui.Widget;
const Control = ui.controls.Control;
const MemoryPool = ui.MemoryPool;
const List = Widget.List;

pool: MemoryPool(Widget),
stack: std.ArrayList(*List),

top_list: List = .{},

/// Starts the construction of a new widget hierarchy, will
/// allocate all widgets inside a memory pool.
pub fn begin(allocator: std.mem.Allocator) Builder {
    return Builder{
        .pool = MemoryPool(Widget).init(allocator),
        .stack = std.ArrayList(*List).init(allocator),
    };
}

/// Cancels the construction process and frees all memory.
/// The builder is unusable after this.
pub fn cancel(builder: *Builder) void {
    builder.pool.deinit();
    builder.stack.deinit();
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
    var out = OutValue{
        .memory = builder.pool,
        .view = ui.View{
            .widgets = builder.top_list,
        },
    };
    builder.stack.deinit();
    builder.* = undefined;
    return out;
}

//////////////////////////////////////

/// Returns a handle to the last added widget.
/// Asserts that a widget was already added.
pub fn current(builder: *Builder) *Widget {
    const list = builder.insertionList();
    return Widget.fromNode(if (list.last) |last| last else unreachable);
}

/// Enters the current widget. The new widgets
/// created from now on will be added to the
/// `current` widget.
pub fn enter(builder: *Builder) !void {
    const list = builder.insertionList();
    const last = Widget.fromNode(if (list.last) |last| last else unreachable);
    try builder.stack.append(&last.children);
}

/// Leaves the `parent()` widget. The new widgets
/// created from now on will be added as siblings
/// to `parent()`.
/// Asserts that the builder is currently in a child scope.
pub fn leave(builder: *Builder) void {
    _ = builder.stack.pop();
}

/// Creates a new memory node, stores the passed control
/// into a new widget, then appends the widget to the current
/// tree level.
/// Returns a pointer to the memoized widget.
pub fn add(builder: *Builder, control: Control) !*Widget {
    const storage = try builder.pool.create();
    errdefer builder.pool.destroy(storage);

    storage.* = Widget{
        .control = control,
    };
    builder.insertionList().append(&storage.siblings);

    return storage;
}

/// Returns the current list of widgets where insertion happens.
fn insertionList(builder: *Builder) *List {
    const stack = builder.stack.items;
    return if (stack.len == 0)
        &builder.top_list
    else
        stack[stack.len - 1];
}
