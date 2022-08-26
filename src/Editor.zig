const std = @import("std");
const zero_graphics = @import("zero-graphics.zig");

const Rectangle = zero_graphics.Rectangle;
const Editor = @This();

pub const GizmoType = enum {
    point,
};

pub const Gizmo = union(GizmoType) {
    point: zero_graphics.Point,
};

const GizmoInternal = struct {
    gizmo: Gizmo,
    changed: bool = false,
};

const Queue = std.TailQueue(GizmoInternal);
const Node = Queue.Node;

node_arena: std.heap.ArenaAllocator,
free_gizmos: Queue = .{},
gizmos: Queue = .{},

focused: ?*GizmoInternal = null,
hovered: ?*GizmoInternal = null,
dragged: ?*GizmoInternal = null,
drag_start: zero_graphics.Point = undefined,

mouse_down: bool = false,
mouse_pos: zero_graphics.Point = undefined,

pub fn init(allocator: std.mem.Allocator) Editor {
    return Editor{
        .node_arena = std.heap.ArenaAllocator.init(allocator),
    };
}

pub fn deinit(self: *Editor) void {
    self.node_arena.deinit();
    self.* = undefined;
}

pub fn addGizmo(self: *Editor, initial: Gizmo) !*Gizmo {
    const node = if (self.free_gizmos.popFirst()) |node|
        node
    else
        try self.node_arena.allocator().create(Node);
    node.* = .{
        .data = .{ .gizmo = initial },
    };
    self.gizmos.append(node);
    return &node.data.gizmo;
}

pub fn removeGizmo(self: *Editor, gizmo: *Gizmo) void {
    const internal = @fieldParentPtr(GizmoInternal, "gizmo", gizmo);
    const node = @fieldParentPtr(Node, "data", internal);

    internal.* = undefined;

    self.gizmos.remove(node);
    self.free_gizmos.append(node);
}

pub fn wasModified(self: Editor, gizmo: *Gizmo) bool {
    _ = self;

    const internal = @fieldParentPtr(GizmoInternal, "gizmo", gizmo);

    return internal.changed;
}

pub fn markHandled(self: Editor, gizmo: *Gizmo) void {
    _ = self;

    const internal = @fieldParentPtr(GizmoInternal, "gizmo", gizmo);
    internal.changed = false;
}

// pub fn update(self: *Self, input: zero_graphics.Input) !void {
//     const mouse_pos = input.pointer_location;

//     self.hovered = hovered;
//     if (input.mouse_state.get(.primary)) {
//         self.focused = self.hovered;
//     }
// }

fn handleFromPos(self: *Editor, screen_position: zero_graphics.Point) ?*GizmoInternal {
    var hovered: ?*GizmoInternal = null;

    var it = self.gizmos.first;
    while (it) |node| : (it = node.next) {
        switch (node.data.gizmo) {
            .point => |point| {
                if (getEditHandleRectangle(point.x, point.y).contains(screen_position)) {
                    hovered = &node.data;
                }
            },
        }
    }

    return hovered;
}

pub fn render(self: Editor, renderer: *zero_graphics.Renderer2D) !void {
    var it = self.gizmos.first;
    while (it) |node| : (it = node.next) {
        switch (node.data.gizmo) {
            .point => |point| {
                try renderer.drawRectangle(
                    getEditHandleRectangle(point.x, point.y),
                    if (self.hovered == @as(?*GizmoInternal, &node.data))
                        zero_graphics.colors.xkcd.white
                    else if (self.focused == @as(?*GizmoInternal, &node.data))
                        zero_graphics.colors.xkcd.lime
                    else
                        zero_graphics.colors.xkcd.green,
                );
            },
        }
    }
}

fn getEditHandleRectangle(x: i16, y: i16) Rectangle {
    const size = 4;
    return Rectangle{
        .x = x - size,
        .y = y - size,
        .width = 2 * size + 1,
        .height = 2 * size + 1,
    };
}

fn processEvent(self: *Editor, event: zero_graphics.Input.Event) !bool {
    switch (event) {
        .pointer_motion => |ev| { // Location
            self.hovered = self.handleFromPos(ev);
            self.mouse_pos = ev;

            if (self.focused) |focused| {
                if (self.mouse_down and self.drag_start.distance2(self.mouse_pos) >= 12) {
                    // start dragging here
                    self.dragged = focused;
                }
            }

            if (self.dragged) |dragged| {
                var dx = self.mouse_pos.x - self.drag_start.x;
                var dy = self.mouse_pos.y - self.drag_start.y;
                self.drag_start = self.mouse_pos;

                dragged.changed = (dx != 0) or (dy != 0);
                switch (dragged.gizmo) {
                    .point => |*point_gizmo| {
                        point_gizmo.x += dx;
                        point_gizmo.y += dy;
                    },
                }
            }

            return false;
        },
        .pointer_press => |ev| { // MouseButton
            switch (ev) {
                .primary => {
                    self.mouse_down = true;
                    self.drag_start = self.mouse_pos;
                    self.focused = self.handleFromPos(self.mouse_pos);
                    if (self.focused == null)
                        return false;
                    return true;
                },
                .secondary => return false,
            }

            return false;
        },
        .pointer_release => |ev| { // MouseButton
            switch (ev) {
                .primary => {
                    self.dragged = null;
                    if (self.mouse_down) {
                        self.mouse_down = false;
                        return true;
                    }
                },
                else => {},
            }
            return false;
        },

        else => return false,
    }
}

pub const InputFilter = zero_graphics.Input.Filter.GenericFilter(Editor, processEvent);

pub fn inputFilter(self: *Editor, source: zero_graphics.Input.Filter) InputFilter {
    return InputFilter{
        .target = self,
        .source = source,
    };
}
