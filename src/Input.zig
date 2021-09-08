const std = @import("std");

const types = @import("zero-graphics.zig");

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

    key_down: Scancode,
    key_up: Scancode,

    pub const TextInput = struct {
        text: []const u8,
        modifiers: Modifiers,
    };
};

pub const Scancode = enum {
    // "inspired" by SDL2

    a,
    b,
    c,
    d,
    e,
    f,
    g,
    h,
    i,
    j,
    k,
    l,
    m,
    n,
    o,
    p,
    q,
    r,
    s,
    t,
    u,
    v,
    w,
    x,
    y,
    z,

    @"1",
    @"2",
    @"3",
    @"4",
    @"5",
    @"6",
    @"7",
    @"8",
    @"9",
    @"0",

    @"return",
    escape,
    backspace,
    tab,
    space,
    minus,
    equals,
    left_bracket,
    right_bracket,
    backslash,
    nonushash,
    semicolon,
    apostrophe,
    grave,
    comma,
    period,
    slash,
    caps_lock,
    print_screen,
    scroll_lock,
    pause,
    insert,
    home,
    page_up,
    delete,
    end,
    page_down,
    right,
    left,
    down,
    up,
    num_lock_clear,

    keypad_divide,
    keypad_multiply,
    keypad_minus,
    keypad_plus,
    keypad_enter,
    keypad_1,
    keypad_2,
    keypad_3,
    keypad_4,
    keypad_5,
    keypad_6,
    keypad_7,
    keypad_8,
    keypad_9,
    keypad_0,
    keypad_00,
    keypad_000,
    keypad_period,
    keypad_comma,
    keypad_equalsas400,
    keypad_leftparen,
    keypad_rightparen,
    keypad_leftbrace,
    keypad_rightbrace,
    keypad_tab,
    keypad_backspace,
    keypad_a,
    keypad_b,
    keypad_c,
    keypad_d,
    keypad_e,
    keypad_f,
    keypad_xor,
    keypad_power,
    keypad_percent,
    keypad_less,
    keypad_greater,
    keypad_ampersand,
    keypad_dblampersand,
    keypad_verticalbar,
    keypad_dblverticalbar,
    keypad_colon,
    keypad_hash,
    keypad_space,
    keypad_at,
    keypad_exclam,
    keypad_memstore,
    keypad_memrecall,
    keypad_memclear,
    keypad_memadd,
    keypad_memsubtract,
    keypad_memmultiply,
    keypad_memdivide,
    keypad_plusminus,
    keypad_clear,
    keypad_clearentry,
    keypad_binary,
    keypad_octal,
    keypad_decimal,
    keypad_hexadecimal,
    keypad_equals,

    f1,
    f2,
    f3,
    f4,
    f5,
    f6,
    f7,
    f8,
    f9,
    f10,
    f11,
    f12,
    f13,
    f14,
    f15,
    f16,
    f17,
    f18,
    f19,
    f20,
    f21,
    f22,
    f23,
    f24,

    nonusbackslash,
    application,
    power,
    execute,
    help,
    menu,
    select,
    stop,
    again,
    undo,
    cut,
    copy,
    paste,
    find,
    mute,
    volumeup,
    volumedown,
    alterase,
    sysreq,
    cancel,
    clear,
    prior,
    return2,
    separator,
    out,
    oper,
    clearagain,
    crsel,
    exsel,
    thousandsseparator,
    decimalseparator,
    currencyunit,
    currencysubunit,
    ctrl_left,
    shift_left,
    alt_left,
    gui_left,
    ctrl_right,
    shift_right,
    alt_right,
    gui_right,
    mode,

    audio_next,
    audio_prev,
    audio_stop,
    audio_play,
    audio_mute,
    audio_rewind,
    audio_fastforward,

    media_select,
    www,
    mail,
    calculator,
    computer,
    ac_search,
    ac_home,
    ac_back,
    ac_forward,
    ac_stop,
    ac_refresh,
    ac_bookmarks,
    brightness_down,
    brightness_up,
    displayswitch,
    kbdillumtoggle,
    kbdillumdown,
    kbdillumup,
    eject,
    sleep,
    app1,
    app2,
};

const EventList = std.TailQueue(Event);
const EventNode = std.TailQueue(Event).Node;

const ScancodeMap = blk: {
    @setEvalBranchQuota(10_000);
    break :blk std.EnumArray(Scancode, bool);
};

const Self = @This();

arena: std.heap.ArenaAllocator,

free_queue: EventList,
event_queue: EventList,
current_event: ?*EventNode,
string_pool: std.ArrayList([]const u8),

/// The current location of the input pointer (moues cursor or touch point).
pointer_location: Location,

keyboard_state: ScancodeMap,

pub fn init(allocator: *std.mem.Allocator) Self {
    return Self{
        .arena = std.heap.ArenaAllocator.init(allocator),
        .string_pool = std.ArrayList([]const u8).init(allocator),
        .free_queue = .{},
        .event_queue = .{},
        .current_event = null,
        .pointer_location = .{ .x = -1, .y = -1 },
        .keyboard_state = ScancodeMap.initFill(false),
    };
}

pub fn deinit(self: *Self) void {
    self.string_pool.deinit();
    self.arena.deinit();
    self.* = undefined;
}

pub fn isPressed(self: Self, key: Scancode) bool {
    return self.keyboard_state.get(key);
}

pub fn isReleased(self: Self, key: Scancode) bool {
    return !self.keyboard_state.get(key);
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
    if (event) |ev| {
        switch (ev) {
            // auto-update keyboard state
            .key_down => |k| self.keyboard_state.set(k, true),
            .key_up => |k| self.keyboard_state.set(k, false),

            // auto-update via motion events
            .pointer_motion => |pos| self.pointer_location = pos,
            else => {},
        }
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
