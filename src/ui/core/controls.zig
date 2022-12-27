const std = @import("std");
const ui = @import("ui.zig");

const raw_control_list = @import("controls");

/// This is an enumeration of all available classes.
pub const ClassID: type = blk: {
    const EnumField = std.builtin.Type.EnumField;

    var fields: []const EnumField = &.{};
    for (std.meta.declarations(raw_control_list)) |decl, index| {
        const class = EnumField{
            .name = decl.name,
            .value = index,
        };
        fields = fields ++ [1]EnumField{class};
    }

    break :blk @Type(.{
        .Enum = .{
            .tag_type = u32,
            .fields = fields,
            .decls = &.{},
            .is_exhaustive = true,
        },
    });
};

/// A meta description that contains all relevant control information
/// for a control class.
pub const ControlClass = struct {
    id: ClassID,
    name: []const u8,
    type: type,
};

/// The list of all available control classes.
pub const classes = blk: {
    var class_list: []const ControlClass = &.{};

    for (std.meta.declarations(raw_control_list)) |decl, index| {
        const class = ControlClass{
            .id = @intToEnum(ClassID, index),
            .name = decl.name,
            .type = @field(raw_control_list, decl.name),
        };

        class_list = class_list ++ [1]ControlClass{class};
    }

    if (class_list.len == 0)
        @compileError("The widget collection is empty. Is your provided widgets package correctly defined?");

    break :blk class_list;
};

/// A union of all possible controls, will be stored inside a widget.
pub const Control: type = blk: {
    const UnionField = std.builtin.Type.UnionField;

    var fields: []const UnionField = &.{};
    for (classes) |class| {
        const field = UnionField{
            .name = class.name,
            .type = class.type,
            .alignment = @alignOf(class.type),
        };
        fields = fields ++ [1]UnionField{field};
    }

    break :blk @Type(.{
        .Union = .{
            .layout = .Auto,
            .tag_type = ClassID,
            .fields = fields,
            .decls = &.{},
        },
    });
};

pub fn className(id: ClassID) []const u8 {
    const T = struct {
        /// The list of all available control classes.
        pub const items = blk: {
            var strings: []const []const u8 = &.{};

            for (std.enums.values(ClassID)) |value, index| {
                std.debug.assert(@enumToInt(value) == index);
                strings = strings ++ [1][]const u8{@tagName(value)};
            }

            break :blk strings;
        };
    };
    return T.items[@enumToInt(id)];
}

////////////////////////////////////////////
// Common widget API:

pub fn init(ctrl: *Control, allocator: std.mem.Allocator) !void {
    switch (ctrl.*) {
        inline else => |*c| if (@hasDecl(@TypeOf(c.*), "init"))
            try c.init(allocator),
    }
}

pub fn deinit(ctrl: *Control) !void {
    switch (ctrl.*) {
        inline else => |*c| if (@hasDecl(@TypeOf(c.*), "deinit"))
            try c.deinit(),
    }
}

pub fn canReceiveFocus(ctrl: *Control) bool {
    return switch (ctrl.*) {
        inline else => |*c| c.canReceiveFocus(),
    };
}

pub fn isHitTestVisible(ctrl: *Control) bool {
    return switch (ctrl.*) {
        inline else => |*c| c.isHitTestVisible(),
    };
}

////////////////////////////////////////////
// Safety checks:

comptime {
    // ensure all controls will be instantiated, and
    // all functions are verified, even if not referenced
    // by any code yet.
    for (std.meta.declarations(@This())) |decl| {
        if (decl.is_pub)
            _ = @field(@This(), decl.name);
    }
}
