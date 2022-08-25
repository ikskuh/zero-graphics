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

pub const Scancode = enum(u16) {
    // "inspired" by SDL2

    a = 1,
    b = 2,
    c = 3,
    d = 4,
    e = 5,
    f = 6,
    g = 7,
    h = 8,
    i = 9,
    j = 10,
    k = 11,
    l = 12,
    m = 13,
    n = 14,
    o = 15,
    p = 16,
    q = 17,
    r = 18,
    s = 19,
    t = 20,
    u = 21,
    v = 22,
    w = 23,
    x = 24,
    y = 25,
    z = 26,
    @"1" = 27,
    @"2" = 28,
    @"3" = 29,
    @"4" = 30,
    @"5" = 31,
    @"6" = 32,
    @"7" = 33,
    @"8" = 34,
    @"9" = 35,
    @"0" = 36,
    @"return" = 37,
    escape = 38,
    backspace = 39,
    tab = 40,
    space = 41,
    minus = 42,
    equals = 43,
    left_bracket = 44,
    right_bracket = 45,
    backslash = 46,
    nonushash = 47,
    semicolon = 48,
    apostrophe = 49,
    grave = 50,
    comma = 51,
    period = 52,
    slash = 53,
    caps_lock = 54,
    print_screen = 55,
    scroll_lock = 56,
    pause = 57,
    insert = 58,
    home = 59,
    page_up = 60,
    delete = 61,
    end = 62,
    page_down = 63,
    right = 64,
    left = 65,
    down = 66,
    up = 67,
    num_lock_clear = 68,
    keypad_divide = 69,
    keypad_multiply = 70,
    keypad_minus = 71,
    keypad_plus = 72,
    keypad_enter = 73,
    keypad_1 = 74,
    keypad_2 = 75,
    keypad_3 = 76,
    keypad_4 = 77,
    keypad_5 = 78,
    keypad_6 = 79,
    keypad_7 = 80,
    keypad_8 = 81,
    keypad_9 = 82,
    keypad_0 = 83,
    keypad_00 = 84,
    keypad_000 = 85,
    keypad_period = 86,
    keypad_comma = 87,
    keypad_equalsas400 = 88,
    keypad_leftparen = 89,
    keypad_rightparen = 90,
    keypad_leftbrace = 91,
    keypad_rightbrace = 92,
    keypad_tab = 93,
    keypad_backspace = 94,
    keypad_a = 95,
    keypad_b = 96,
    keypad_c = 97,
    keypad_d = 98,
    keypad_e = 99,
    keypad_f = 100,
    keypad_xor = 101,
    keypad_power = 102,
    keypad_percent = 103,
    keypad_less = 104,
    keypad_greater = 105,
    keypad_ampersand = 106,
    keypad_dblampersand = 107,
    keypad_verticalbar = 108,
    keypad_dblverticalbar = 109,
    keypad_colon = 110,
    keypad_hash = 111,
    keypad_space = 112,
    keypad_at = 113,
    keypad_exclam = 114,
    keypad_memstore = 115,
    keypad_memrecall = 116,
    keypad_memclear = 117,
    keypad_memadd = 118,
    keypad_memsubtract = 119,
    keypad_memmultiply = 120,
    keypad_memdivide = 121,
    keypad_plusminus = 122,
    keypad_clear = 123,
    keypad_clearentry = 124,
    keypad_binary = 125,
    keypad_octal = 126,
    keypad_decimal = 127,
    keypad_hexadecimal = 128,
    keypad_equals = 129,
    f1 = 130,
    f2 = 131,
    f3 = 132,
    f4 = 133,
    f5 = 134,
    f6 = 135,
    f7 = 136,
    f8 = 137,
    f9 = 138,
    f10 = 139,
    f11 = 140,
    f12 = 141,
    f13 = 142,
    f14 = 143,
    f15 = 144,
    f16 = 145,
    f17 = 146,
    f18 = 147,
    f19 = 148,
    f20 = 149,
    f21 = 150,
    f22 = 151,
    f23 = 152,
    f24 = 153,
    nonusbackslash = 154,
    application = 155,
    power = 156,
    execute = 157,
    help = 158,
    menu = 159,
    select = 160,
    stop = 161,
    again = 162,
    undo = 163,
    cut = 164,
    copy = 165,
    paste = 166,
    find = 167,
    mute = 168,
    volumeup = 169,
    volumedown = 170,
    alterase = 171,
    sysreq = 172,
    cancel = 173,
    clear = 174,
    prior = 175,
    return2 = 176,
    separator = 177,
    out = 178,
    oper = 179,
    clearagain = 180,
    crsel = 181,
    exsel = 182,
    thousandsseparator = 183,
    decimalseparator = 184,
    currencyunit = 185,
    currencysubunit = 186,
    ctrl_left = 187,
    shift_left = 188,
    alt_left = 189,
    gui_left = 190,
    ctrl_right = 191,
    shift_right = 192,
    alt_right = 193,
    gui_right = 194,
    mode = 195,
    audio_next = 196,
    audio_prev = 197,
    audio_stop = 198,
    audio_play = 199,
    audio_mute = 200,
    audio_rewind = 201,
    audio_fastforward = 202,
    media_select = 203,
    www = 204,
    mail = 205,
    calculator = 206,
    computer = 207,
    ac_search = 208,
    ac_home = 209,
    ac_back = 210,
    ac_forward = 211,
    ac_stop = 212,
    ac_refresh = 213,
    ac_bookmarks = 214,
    brightness_down = 215,
    brightness_up = 216,
    displayswitch = 217,
    kbdillumtoggle = 218,
    kbdillumdown = 219,
    kbdillumup = 220,
    eject = 221,
    sleep = 222,
    app1 = 223,
    app2 = 224,
};

const EventList = std.TailQueue(Event);
const EventNode = std.TailQueue(Event).Node;

const ScancodeMap = blk: {
    @setEvalBranchQuota(10_000);
    break :blk std.EnumArray(Scancode, bool);
};
const ButtonMap = blk: {
    @setEvalBranchQuota(10_000);
    break :blk std.EnumArray(MouseButton, bool);
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
mouse_state: ButtonMap,

pub fn init(allocator: std.mem.Allocator) Self {
    return Self{
        .arena = std.heap.ArenaAllocator.init(allocator),
        .string_pool = std.ArrayList([]const u8).init(allocator),
        .free_queue = .{},
        .event_queue = .{},
        .current_event = null,
        .pointer_location = .{ .x = -1, .y = -1 },
        .keyboard_state = ScancodeMap.initFill(false),
        .mouse_state = ButtonMap.initFill(false),
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

pub fn fetch(self: *Self) ?Event {
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
            .pointer_press => |b| self.mouse_state.set(b, true),
            .pointer_release => |b| self.mouse_state.set(b, false),

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

    const dupe = try self.arena.allocator().dupe(u8, str);
    try self.string_pool.append(dupe);
    return dupe;
}

pub fn pushEvent(self: *Self, event: Event) !void {
    const node = if (self.free_queue.popFirst()) |n|
        n
    else
        try self.arena.allocator().create(EventNode);
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
