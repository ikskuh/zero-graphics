const std = @import("std");

const Renderer = @import("rendering/Renderer2D.zig");

pub const Rectangle = struct {
    x: i16,
    y: i16,
    width: u15,
    height: u15,
};

pub const Theme = struct {
    button_border: Renderer.Color,
    button_background: Renderer.Color,
    button_text: Renderer.Color,

    pub const default = Theme{
        .button_border = .{ .r = 0xCC, .g = 0xCC, .b = 0xCC },
        .button_background = .{ .r = 0x30, .g = 0x30, .b = 0x30 },
        .button_text = .{ .r = 0xFF, .g = 0xFF, .b = 0xFF },
    };
};

const WidgetID = enum(u32) { _ };

const Widget = struct {
    id: WidgetID,
    control: Control,
    bounds: Rectangle,

    const Control = union(enum) {
        unset,
        button: Button,
        text_box: TextBox,
        label: Label,
        check_box: CheckBox,
        radio_button: RadioButton,
    };

    const Button = struct {
        pub const Config = struct {
            text_color: ?Renderer.Color = null,
            font: ?*const Renderer.Font = null,
        };
        text: StringBuffer,
        config: Config,
    };
    const TextBox = struct {
        text: StringBuffer,
    };
    const Label = struct {
        text: StringBuffer,
    };
    const CheckBox = struct {
        is_checked: bool,
    };
    const RadioButton = struct {
        is_checked: bool,
        group: u32, // buttons are grouped by this
    };
};

const WidgetType = std.meta.TagType(Widget.Control);

const WidgetList = std.TailQueue(Widget);
const WidgetNode = std.TailQueue(Widget).Node;

const UserInterface = @This();

allocator: *std.mem.Allocator,
arena: std.heap.ArenaAllocator,

/// Contains the sequence of widgets that were created between
/// `.begin()` and `.end()`. All widgets in this list are active in
/// the current frame.
active_widgets: WidgetList = .{},

/// Contains the list of all widgets that were available in the last 
/// frame. Widgets in here have valid `.data` and might be re-used in 
/// the current frame. This allows keeping state over several frames.
retained_widgets: WidgetList = .{},

/// Contains nodes that are not used right now and free for allocation
/// `WidgetNode.data` contains garbage and must be freshly initialized.
free_widgets: WidgetList = .{},

theme: *const Theme = &Theme.default,

default_font: *const Renderer.Font,

pub fn init(allocator: *std.mem.Allocator, default_font: *const Renderer.Font) UserInterface {
    return UserInterface{
        .default_font = default_font,
        .allocator = allocator,
        .arena = std.heap.ArenaAllocator.init(allocator),
    };
}

pub fn deinit(self: *UserInterface) void {
    self.arena.deinit();
    self.* = undefined;
}

/// Allocates a new WidgetNode, either via the arena or 
/// fetches it from the free_widgets list
fn allocWidgetNode(self: *UserInterface) !*WidgetNode {
    const node = if (self.free_widgets.popFirst()) |n|
        n
    else
        try self.arena.allocator.create(WidgetNode);
    node.* = .{
        .data = undefined,
    };
    return node;
}

/// Marks the WidgetNode as invalid and moves it into the free_widgets list for
/// later reallocation.
fn freeWidgetNode(self: *UserInterface, node: *WidgetNode) void {
    node.data = undefined;
    self.free_widgets.append(node);
}

/// Fetches a fitting widget from the `retained_widgets` list or creates a new node.
/// On success, the widget is appended to the `active_widgets` list.
fn findOrAllocWidget(self: *UserInterface, widget_type: WidgetType, id: WidgetID) !*Widget {
    var it = self.retained_widgets.first;
    while (it) |node| : (it = node.next) {
        if (node.data.id == id) {
            // When this assertion is true, we created the same ID twice
            // for different widget invocations. This means we must increase the number of bits
            // in WidgetID and adjust our hash function
            std.debug.assert(node.data.control == widget_type);

            // Shuffle from one list into the other:
            self.retained_widgets.remove(node);
            self.active_widgets.append(node);

            return &node.data;
        }
    }

    const node = try self.allocWidgetNode();
    node.data = Widget{
        .id = id,
        .control = .unset,
        .bounds = undefined,
    };
    self.active_widgets.append(node);
    return &node.data;
}

/// Starts a UI pass and collects widgets.
/// Widgets are then created with calls to `.button`, `.textBox`, ... until `.end()` is called.
pub fn begin(self: *UserInterface) void {
    // Moves all active widgets into the retained storage.
    // Widgets will be pulled from there when reused, otherwise will be destroyed in `.end()`.
    while (self.active_widgets.popFirst()) |node| {
        self.retained_widgets.append(node);
    }
}

/// Ends the current UI pass and stops collecting widgets.
/// Will destroy all remaining widgets in `retained_widgets`
/// that are left, as those must be recreated when used the next time.
pub fn end(self: *UserInterface) void {
    while (self.retained_widgets.popFirst()) |node| {
        // TODO: Destroy widget data here!
        self.freeWidgetNode(node);
    }
}

/// Returns a unqiue identifier for each type.
fn typeId(comptime T: type) usize {
    return comptime @ptrToInt(&struct {
        var i: u8 = 0;
    }.i);
}

/// Computes a adler32 ID from the 
fn widgetId(config: anytype) WidgetID {
    const Config = @TypeOf(config);

    var hash = std.hash.Adler32.init();
    hash.update(std.mem.asBytes(&typeId(Config)));
    if (@hasField(Config, "id"))
        hash.update(std.mem.asBytes(&config.id));

    return @intToEnum(WidgetID, hash.final());
}

fn updateWidgetConfig(dst_config: anytype, src_config: anytype) void {
    inline for (std.meta.fields(@TypeOf(src_config))) |fld| {
        if (comptime !std.mem.eql(u8, fld.name, "id")) {
            @field(dst_config, fld.name) = @field(src_config, fld.name);
        }
    }
}

pub fn button(self: *UserInterface, rectangle: Rectangle, text: []const u8, config: anytype) !bool {
    const widget = try self.findOrAllocWidget(.button, widgetId(config));
    widget.bounds = rectangle;
    switch (widget.control) {
        // fresh widget
        .unset => {
            widget.control = .{
                .button = .{
                    .text = try StringBuffer.init(self.allocator, text),
                    .config = .{},
                },
            };
        },
        // already exists
        .button => |*btn| {
            try btn.text.set(self.allocator, text);
        },
        else => unreachable,
    }

    updateWidgetConfig(&widget.control.button.config, config);

    return false;
}

pub fn label(self: *UserInterface, rectangle: Rectangle, text: []const u8, config: anytype) !void {
    const widget = try self.findOrAllocWidget(.label, widgetId(config));
    widget.bounds = rectangle;
    switch (widget.control) {
        // fresh widget
        .unset => {
            widget.control = .{
                .label = .{
                    .text = try StringBuffer.init(self.allocator, text),
                },
            };
        },
        // already exists
        .label => |*lbl| {
            try lbl.text.set(self.allocator, text);
        },
        else => unreachable,
    }
}

pub fn render(self: UserInterface, renderer: *Renderer) !void {
    var iterator = self.active_widgets.first;
    while (iterator) |node| : (iterator = node.next) {
        const widget = &node.data;
        switch (widget.control) {
            // unset is only required for allocating fresh nodes and then initialize them properly in the
            // corresponding widget function
            .unset => unreachable,

            .button => |control| {
                try renderer.fillRectangle(widget.bounds.x, widget.bounds.y, widget.bounds.width, widget.bounds.height, self.theme.button_background);
                try renderer.drawRectangle(widget.bounds.x, widget.bounds.y, widget.bounds.width, widget.bounds.height, self.theme.button_border);

                try renderer.drawString(
                    control.config.font orelse self.default_font,
                    control.text.get(),
                    widget.bounds.x + 2,
                    widget.bounds.y + 2,
                    control.config.text_color orelse self.theme.button_text,
                );
            },
            .text_box => |control| {
                @panic("not implemented yet!");
            },
            .label => |control| {
                @panic("not implemented yet!");
            },
            .check_box => |control| {
                @panic("not implemented yet!");
            },
            .radio_button => |control| {
                @panic("not implemented yet!");
            },
        }
    }
}

fn getListLength(list: WidgetList) usize {
    var it = list.first;
    var len: usize = 0;
    while (it) |node| : (it = node.next) {
        len += 1;
    }
    return len;
}

test "basic widget collection" {
    var ui = init(std.testing.allocator);
    defer ui.deinit();

    {
        ui.begin();
        defer ui.end();

        _ = try ui.button(undefined, "Cancel", .{});
        _ = try ui.button(undefined, "Ok", .{});

        var i: usize = 0;
        while (i < 3) : (i += 1) {
            _ = try ui.button(undefined, "List Button", .{ .id = i });
        }
        try ui.label(undefined, "Hello", .{});
    }
    try std.testing.expectEqual(@as(usize, 0), getListLength(ui.retained_widgets));
    try std.testing.expectEqual(@as(usize, 0), getListLength(ui.free_widgets));
    try std.testing.expectEqual(@as(usize, 6), getListLength(ui.active_widgets));
}

test "widget re-collection" {

    // Tests if widgets are properly re-collected in consecutive loops, even
    // if not all widgets are reused

    var ui = init(std.testing.allocator);
    defer ui.deinit();

    var i: usize = 0;
    while (i < 10) : (i += 1) {
        {
            ui.begin();
            defer ui.end();

            if (i == 0) {
                _ = try ui.button(undefined, "Ok", .{});
                _ = try ui.button(undefined, "Cancel", .{});
            }

            var j: usize = 0;
            while (j < 3) : (j += 1) {
                _ = try ui.button(undefined, "Listed Button", .{ .id = j });
            }
            try ui.label(undefined, "Hello", .{});

            if (i == 1) {
                // test that the two buttons from the first frame are properly retained until the end,
                // and then freed:
                try std.testing.expectEqual(@as(usize, 2), getListLength(ui.retained_widgets));
            }
        }

        // Retained must always be empty after ui.end()!
        try std.testing.expectEqual(@as(usize, 0), getListLength(ui.retained_widgets));

        if (i == 0) {
            try std.testing.expectEqual(@as(usize, 0), getListLength(ui.free_widgets));
            try std.testing.expectEqual(@as(usize, 6), getListLength(ui.active_widgets));
        } else {
            try std.testing.expectEqual(@as(usize, 2), getListLength(ui.free_widgets)); // two conditional widgets
            try std.testing.expectEqual(@as(usize, 4), getListLength(ui.active_widgets)); // four unconditional widgets
        }
    }
}

/// A dynamic, potentially allocated string buffer that can store texts.
const StringBuffer = union(enum) {
    const Self = @This();

    self_contained: ArrayBuffer,
    allocated: std.ArrayList(u8),

    const ArrayBuffer = struct {
        const max_len = 3 * @sizeOf(usize);
        len: usize,
        items: [max_len]u8,
    };

    pub fn init(allocator: *std.mem.Allocator, string: []const u8) !Self {
        var self = Self{ .self_contained = undefined };
        try self.set(allocator, string);
        return self;
    }

    pub fn deinit(self: *Self) void {
        if (self.* == .allocated) {
            self.allocated.deinit();
        }
        self.* = undefined;
    }

    pub fn get(self: *const Self) []const u8 {
        return switch (self.*) {
            .allocated => |*list| list.items,
            .self_contained => |*str| str.items[0..str.len],
        };
    }

    pub fn set(self: *Self, allocator: *std.mem.Allocator, string: []const u8) !void {
        switch (self.*) {
            .allocated => |*list| {
                try list.resize(string.len);
                std.mem.copy(u8, list.items, string);
            },
            else => {
                if (string.len <= ArrayBuffer.max_len) {
                    self.* = Self{
                        .self_contained = .{
                            .items = undefined,
                            .len = string.len,
                        },
                    };
                    std.mem.copy(u8, self.self_contained.items[0..string.len], string);
                } else {
                    self.* = Self{
                        .allocated = std.ArrayList(u8).init(allocator),
                    };
                    try self.allocated.resize(string.len);
                    std.mem.copy(u8, self.allocated.items, string);
                }
            },
        }
    }
};

test "StringBuffer" {
    var buf = try StringBuffer.init(std.testing.allocator, "Hello");
    defer buf.deinit();

    try std.testing.expectEqualStrings("Hello", buf.get());

    try buf.set(std.testing.allocator, "");
    try std.testing.expectEqualStrings("", buf.get());

    const long_string = "Hello, i am a very long string that is self-contained and should probably exceed the length of a StringBuffer by far!";
    try buf.set(std.testing.allocator, long_string);
    try std.testing.expectEqualStrings(long_string, buf.get());
}
