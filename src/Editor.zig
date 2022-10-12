const std = @import("std");
const zero_graphics = @import("zero-graphics.zig");

const Rectangle = zero_graphics.Rectangle;
const Color = zero_graphics.Color;
const Point = zero_graphics.Point;
const Editor = @This();

pub const Gizmo = struct {
    data: Data,
    changed: bool = false,
    frame_index: u32,
    tag: usize,

    pub const Data = union(Type) {
        point: zero_graphics.Point,
    };

    pub const Type = enum {
        point,
    };
};

const Queue = std.TailQueue(Gizmo);
const Node = Queue.Node;

node_arena: std.heap.ArenaAllocator,
free_gizmos: Queue = .{},
gizmos: Queue = .{},

focused: ?*Gizmo = null,
hovered: ?*Gizmo = null,
dragged: ?*Gizmo = null,
drag_start: zero_graphics.Point = undefined,
drag_data: Gizmo.Data = undefined,

mouse_down: bool = false,
mouse_pos: zero_graphics.Point = undefined,

frame_index: u32 = 0,

pub fn init(allocator: std.mem.Allocator) Editor {
    return Editor{
        .node_arena = std.heap.ArenaAllocator.init(allocator),
    };
}

pub fn deinit(self: *Editor) void {
    self.node_arena.deinit();
    self.* = undefined;
}

pub fn notifyNewCycle(self: *Editor) !void {
    var it = self.gizmos.first;

    while (it) |node| {
        it = node.next;

        if (node.data.frame_index != self.frame_index) {
            // remove all nodes that were not touched
            // in the last frame
            self.gizmos.remove(node);

            node.data = undefined;

            self.free_gizmos.append(node);
        }
    }

    self.frame_index +%= 1;
}

fn createGizmo(self: *Editor) !*Gizmo {
    const node = if (self.free_gizmos.popFirst()) |node|
        node
    else
        try self.node_arena.allocator().create(Node);
    node.* = .{ .data = undefined };
    self.gizmos.append(node);
    return &node.data;
}

const GetGizmoResult = struct {
    gizmo: *Gizmo,
    cached: bool,
};

fn makeTagValue(value: anytype) usize {
    const T = @TypeOf(value);
    return switch (@typeInfo(T)) {
        .Pointer => @ptrToInt(value),
        .Int => |int| if (int.signedness == .signed)
            @bitCast(usize, @as(isize, value))
        else
            @as(usize, value),

        else => @compileError(@typeName(T) ++ " is not a possible tag type"),
    };
}

/// Gets or creates a new gizmo based on `tag`.
/// If the `cached` flag in the return value is set,
/// `.data` of the gizmo is already initialized with data from
/// the last frame, otherwise a new gizmo was created.
fn getGizmo(self: *Editor, tag: anytype, kind: Gizmo.Type) !GetGizmoResult {
    const tag_val = makeTagValue(tag);

    var it = self.gizmos.first;
    while (it) |node| : (it = node.next) {
        if (node.data.tag == tag_val) {
            // mark the gizmo to be used in this frame
            node.data.frame_index = self.frame_index;
            return GetGizmoResult{
                .gizmo = &node.data,

                // return cached only when the gizmo has the same type
                .cached = (node.data.data == kind),
            };
        }
    }

    const gizmo = try self.createGizmo();
    gizmo.* = .{
        .tag = tag_val,
        .frame_index = self.frame_index,
        .changed = false,
        .data = undefined,
    };
    return GetGizmoResult{
        .gizmo = gizmo,
        .cached = false,
    };
}

pub fn editPoint2D(self: *Editor, tag: anytype, position: Point) !?Point {
    const ggr = try self.getGizmo(tag, .point);

    defer {
        ggr.gizmo.changed = false;
        ggr.gizmo.data.point = position;
    }

    if (ggr.cached) {
        return if (ggr.gizmo.changed)
            ggr.gizmo.data.point
        else
            return null;
    } else {
        // initialize
        ggr.gizmo.data = .{ .point = position };
        return null;
    }
}

// pub fn update(self: *Self, input: zero_graphics.Input) !void {
//     const mouse_pos = input.pointer_location;

//     self.hovered = hovered;
//     if (input.mouse_state.get(.primary)) {
//         self.focused = self.hovered;
//     }
// }

fn handleFromPos(self: *Editor, screen_position: zero_graphics.Point) ?*Gizmo {
    var hovered: ?*Gizmo = null;

    var it = self.gizmos.first;
    while (it) |node| : (it = node.next) {
        switch (node.data.data) {
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
        switch (node.data.data) {
            .point => |point| {
                try renderer.drawRectangle(
                    getEditHandleRectangle(point.x, point.y),
                    Color.magenta,
                    // if (self.hovered == @as(?*Gizmo, &node.data))
                    //     zero_graphics.colors.xkcd.white
                    // else if (self.focused == @as(?*Gizmo, &node.data))
                    //     zero_graphics.colors.xkcd.lime
                    // else
                    //     zero_graphics.colors.xkcd.green,
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

                if ((dx != 0) or (dy != 0)) {
                    dragged.changed = true;
                }
                switch (dragged.data) {
                    .point => |*point_gizmo| {
                        point_gizmo.x = self.drag_data.point.x + dx;
                        point_gizmo.y = self.drag_data.point.y + dy;
                    },
                }
                return true;
            }

            return false;
        },
        .pointer_press => |ev| { // MouseButton
            switch (ev) {
                .primary => {
                    const focused = self.handleFromPos(self.mouse_pos) orelse return false;
                    self.mouse_down = true;
                    self.drag_start = self.mouse_pos;
                    self.focused = focused;
                    self.drag_data = focused.data;
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
                        self.drag_data = undefined;
                        self.mouse_down = false;
                        return (self.focused != null);
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
