const std = @import("std");

const types = @import("common.zig");

const Location = types.Point;

pub const MouseButton = enum {
    primary,
    secondary,
};

pub const Modifiers = struct {
    shift: bool = false,
    ctrl: bool = false,
    alt: bool = false,
    super: bool = false,
};

pub const Event = union(enum) {
    quit,
    pointer_motion: Location,
    pointer_press: MouseButton,
    pointer_release: MouseButton,
    text_input: TextInput,

    pub const TextInput = struct {
        text: []const u8,
        modifiers: Modifiers,
    };
};

const EventList = std.TailQueue(Event);
const EventNode = std.TailQueue(Event).Node;

const Self = @This();

arena: std.heap.ArenaAllocator,

free_queue: EventList,
event_queue: EventList,
current_event: ?*EventNode,
string_pool: std.ArrayList([]const u8),

/// The current location of the input pointer (moues cursor or touch point).
pointer_location: Location,

pub fn init(allocator: *std.mem.Allocator) Self {
    return Self{
        .arena = std.heap.ArenaAllocator.init(allocator),
        .string_pool = std.ArrayList([]const u8).init(allocator),
        .free_queue = .{},
        .event_queue = .{},
        .current_event = null,
        .pointer_location = .{ .x = -1, .y = -1 },
    };
}

pub fn deinit(self: *Self) void {
    self.string_pool.deinit();
    self.arena.deinit();
    self.* = undefined;
}

pub fn pollEvent(self: *Self) ?Event {
    if (self.current_event) |node| {
        node.data = undefined;
        self.free_queue.append(node);
    }
    self.current_event = self.event_queue.popFirst();
    const event = if (self.current_event) |node|
        node.data
    else
        null;
    // auto-update via motion events
    if (event != null and event.? == .pointer_motion) {
        self.pointer_location = event.?.pointer_motion;
    }
    return event;
}

fn poolString(self: *Self, str: []const u8) ![]const u8 {
    for (self.string_pool.items) |item| {
        if (std.mem.indexOf(u8, item, str)) |index| {
            return item[index .. index + str.len];
        }
    }
    const dupe = try self.arena.allocator.dupe(u8, str);
    try self.string_pool.append(dupe);
    return dupe;
}

pub fn pushEvent(self: *Self, event: Event) !void {
    const node = if (self.free_queue.popFirst()) |n|
        n
    else
        try self.arena.allocator.create(EventNode);
    errdefer self.free_queue.append(node);

    node.* = .{
        .data = switch (event) {
            .text_input => |ti| Event{
                // text input strings are pushed into the string pool
                .text_input = Event.TextInput{
                    .text = try self.poolString(ti.text),
                    .modifiers = ti.modifiers,
                },
            },
            else => event,
        },
    };
    self.event_queue.append(node);
}

test "push/poll" {
    var queue = init(std.testing.allocator);
    defer queue.deinit();

    try queue.pushEvent(.quit);
    try queue.pushEvent(.{ .pointer_press = .primary });
    try queue.pushEvent(.{ .pointer_press = .secondary });

    try std.testing.expectEqual(@as(?Event, Event{ .quit = {} }), queue.pollEvent());
    try std.testing.expectEqual(@as(?Event, Event{ .pointer_press = .primary }), queue.pollEvent());
    try std.testing.expectEqual(@as(?Event, Event{ .pointer_press = .secondary }), queue.pollEvent());
    try std.testing.expectEqual(@as(?Event, null), queue.pollEvent());
}

test "string pooling" {
    var queue = init(std.testing.allocator);
    defer queue.deinit();

    const str_0 = try queue.poolString("hello");
    const str_1 = try queue.poolString("hello");
    const str_2 = try queue.poolString("lo");

    try std.testing.expectEqual(str_0, str_1);
    try std.testing.expectEqual(str_0[3..], str_2);
}

test "pool text_input events" {
    var queue = init(std.testing.allocator);
    defer queue.deinit();

    var str_0 = "hel".*;
    var str_1 = "lo".*;

    try queue.pushEvent(.{ .text_input = .{ .text = &str_0, .modifiers = .{} } });
    str_0 = "XXX".*;

    try queue.pushEvent(.{ .text_input = .{ .text = &str_1, .modifiers = .{} } });
    str_1 = "YY".*;

    try std.testing.expectEqualStrings("hel", queue.pollEvent().?.text_input.text);
    try std.testing.expectEqualStrings("lo", queue.pollEvent().?.text_input.text);
}
