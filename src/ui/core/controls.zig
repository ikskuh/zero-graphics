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
            .layout = .Auto,
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
            .field_type = class.type,
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
                strings = strings ++ [1][]const u8{@tagName(ClassID)};
            }

            break :blk strings;
        };
    };
    return T.items[@enumToInt(id)];
}
