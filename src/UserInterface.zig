const std = @import("std");
const types = @import("types.zig");
const logger = std.log.scoped(.user_interface);

const Point = types.Point;
const Rectangle = types.Rectangle;

const Renderer = @import("rendering/Renderer2D.zig");

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
    // Control state:
    id: WidgetID,
    control: Control,
    bounds: Rectangle,

    // Runtime state:
    focused: bool = false,

    const Control = union(enum) {
        unset,
        panel: Panel,
        button: Button,
        text_box: TextBox,
        label: Label,
        check_box: CheckBox,
        radio_button: RadioButton,
    };

    pub fn isHitTestVisible(self: Widget) bool {
        return switch (self.control) {
            .unset => unreachable,
            .panel => true,
            .button => true,
            .text_box => true,
            .label => false,
            .check_box => true,
            .radio_button => true,
        };
    }

    const Button = struct {
        pub const Config = struct {
            text_color: ?Renderer.Color = null,
            font: ?*const Renderer.Font = null,
        };
        text: StringBuffer,
        config: Config,
    };
    const Panel = struct {};
    const TextBox = struct {
        text: StringBuffer,
    };
    const Label = struct {
        pub const Config = struct {
            text_color: ?Renderer.Color = null,
            font: ?*const Renderer.Font = null,
            vertical_alignment: types.VerticalAlignment = .center,
            horizontal_alignment: types.HorzizontalAlignment = .left,
        };

        text: StringBuffer,
        config: Config,
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

const ProcessingMode = enum { default, updating, building };

allocator: *std.mem.Allocator,
arena: std.heap.ArenaAllocator,

/// The current mode. This is used to interlock building and updating APIs
mode: ProcessingMode = .default,

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

/// The theme that is used to render the UI.
/// Contains all colors and sizes for widgets.
theme: *const Theme = &Theme.default,

/// The default font the renderer will use to render text in its widgets.
default_font: *const Renderer.Font,

/// Current location of the mouse cursor or finger
pointer_position: Point,

pub fn init(allocator: *std.mem.Allocator, default_font: *const Renderer.Font) UserInterface {
    return UserInterface{
        .default_font = default_font,
        .allocator = allocator,
        .arena = std.heap.ArenaAllocator.init(allocator),
        .pointer_position = Point{
            .x = std.math.minInt(i16),
            .y = std.math.minInt(i16),
        },
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

/// Starts a UI pass and collects widgets. The return value can be used to create new widgets.
/// Call `finish()` on the returned builder to complete the construction.
/// Widgets are then created with calls to `.button`, `.textBox`, ... until `.finish()` is called.
pub fn construct(self: *UserInterface) Builder {
    std.debug.assert(self.mode == .default);
    self.mode = .building;

    // Moves all active widgets into the retained storage.
    // Widgets will be pulled from there when reused, otherwise will be destroyed in `.end()`.
    while (self.active_widgets.popFirst()) |node| {
        self.retained_widgets.append(node);
    }

    return Builder{
        .ui = self,
    };
}

pub const Builder = struct {
    const Self = @This();

    ui: *UserInterface,

    /// Ends the UI construction pass and stops collecting widgets.
    /// Will destroy all remaining widgets in `retained_widgets`
    /// that are left, as those must be recreated when used the next time.
    pub fn finish(self: *Self) void {
        std.debug.assert(self.ui.mode == .building);
        self.ui.mode = .default;

        while (self.ui.retained_widgets.popFirst()) |node| {
            // TODO: Destroy widget data here!
            self.ui.freeWidgetNode(node);
        }

        self.* = undefined;
    }

    pub fn button(self: Self, rectangle: Rectangle, text: []const u8, config: anytype) !bool {
        const widget = try self.ui.findOrAllocWidget(.button, widgetId(config));
        widget.bounds = rectangle;
        switch (widget.control) {
            // fresh widget
            .unset => {
                widget.control = .{
                    .button = .{
                        .text = try StringBuffer.init(self.ui.allocator, text),
                        .config = .{},
                    },
                };
            },
            // already exists
            .button => |*btn| {
                try btn.text.set(self.ui.allocator, text);
            },
            else => unreachable,
        }

        updateWidgetConfig(&widget.control.button.config, config);

        return false;
    }

    pub fn label(self: Self, rectangle: Rectangle, text: []const u8, config: anytype) !void {
        const widget = try self.ui.findOrAllocWidget(.label, widgetId(config));
        widget.bounds = rectangle;
        switch (widget.control) {
            // fresh widget
            .unset => {
                widget.control = .{
                    .label = .{
                        .text = try StringBuffer.init(self.ui.allocator, text),
                    },
                };
            },
            // already exists
            .label => |*lbl| {
                try lbl.text.set(self.ui.allocator, text);
            },
            else => unreachable,
        }

        updateWidgetConfig(&widget.control.label.config, config);
    }
};

pub fn processInput(self: *UserInterface) InputProcessor {
    std.debug.assert(self.mode == .default);
    self.mode = .updating;
    return InputProcessor{
        .ui = self,
    };
}

pub const InputProcessor = struct {
    const Self = @This();

    ui: *UserInterface,

    pub fn finish(self: *Self) void {
        std.debug.assert(self.ui.mode == .updating);
        self.ui.mode = .default;
        self.* = undefined;
    }

    pub fn setPointer(self: Self, position: Point) void {
        self.ui.pointer_position = position;
    }

    pub fn pointerDown(self: Self) void {
        logger.info("not implemented yet: pointerDown", .{});
    }

    pub fn pointerUp(self: Self) void {
        logger.info("not implemented yet: pointerUp", .{});
    }

    pub fn enterText(self: Self, string: []const u8) !void {
        logger.info("not implemented yet: enterText", .{});
    }
};

pub fn render(self: UserInterface, renderer: *Renderer) !void {
    var iterator = self.widgetIterator(.draw_order);
    while (iterator.next()) |widget| {
        switch (widget.control) {
            // unset is only required for allocating fresh nodes and then initialize them properly in the
            // corresponding widget function
            .unset => unreachable,

            .button => |control| {
                try renderer.fillRectangle(widget.bounds.x, widget.bounds.y, widget.bounds.width, widget.bounds.height, self.theme.button_background);
                try renderer.drawRectangle(widget.bounds.x, widget.bounds.y, widget.bounds.width, widget.bounds.height, self.theme.button_border);
                const font = control.config.font orelse self.default_font;
                const string_size = renderer.measureString(font, control.text.get());
                try renderer.drawString(
                    font,
                    control.text.get(),
                    widget.bounds.x + 2 + (widget.bounds.width - 4 - string_size.width) / 2,
                    widget.bounds.y + 2 + (widget.bounds.height - 4 - string_size.height) / 2,
                    control.config.text_color orelse self.theme.button_text,
                );
            },

            .panel => |control| {
                try renderer.fillRectangle(widget.bounds.x, widget.bounds.y, widget.bounds.width, widget.bounds.height, self.theme.button_background);
                try renderer.drawRectangle(widget.bounds.x, widget.bounds.y, widget.bounds.width, widget.bounds.height, self.theme.button_border);
            },

            .text_box => |control| {
                @panic("not implemented yet!");
            },
            .label => |control| {
                const font = control.config.font orelse self.default_font;
                const string_size = renderer.measureString(font, control.text.get());
                try renderer.drawString(
                    font,
                    control.text.get(),
                    widget.bounds.x + switch (control.config.horizontal_alignment) {
                        .left => 0,
                        .center => (widget.bounds.width - string_size.width) / 2,
                        .right => widget.bounds.width - 4 - string_size.width,
                    },
                    widget.bounds.y + switch (control.config.vertical_alignment) {
                        .top => 0,
                        .center => (widget.bounds.height - string_size.height) / 2,
                        .bottom => widget.bounds.height - string_size.height,
                    },
                    control.config.text_color orelse self.theme.button_text,
                );
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

const WidgetOrder = enum { draw_order, event_order };

fn widgetIterator(self: UserInterface, order: WidgetOrder) WidgetIterator {
    return switch (order) {
        .draw_order => WidgetIterator{
            .order = .draw_order,
            .it = self.active_widgets.first,
        },
        .event_order => WidgetIterator{
            .order = .event_order,
            .it = self.active_widgets.last,
        },
    };
}

const WidgetIterator = struct {
    order: WidgetOrder,
    it: ?*WidgetNode,

    pub fn next(self: *@This()) ?*Widget {
        while (true) {
            const result = self.it;
            if (result) |node| {
                self.it = switch (self.order) {
                    .draw_order => node.next,
                    .event_order => node.prev,
                };

                if (self.order == .event_order) {
                    // don't iterate over widgets that cannot receive events
                    if (!node.data.isHitTestVisible())
                        continue;
                }
                return &node.data;
            } else {
                return null;
            }
        }
    }
};

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
