const std = @import("std");
const builtin = @import("builtin");
const zerog = @import("zero-graphics.zig");
const logger = std.log.scoped(.zero_graphics);

fn QueryExtension(comptime query: []const []const u8) type {
    var fields: [query.len]std.builtin.TypeInfo.StructField = undefined;
    for (fields) |*fld, i| {
        fld.* = std.builtin.TypeInfo.StructField{
            .name = query[i],
            .field_type = bool,
            .default_value = false,
            .is_comptime = false,
            .alignment = @alignOf(bool),
        };
    }
    return @Type(.{
        .Struct = std.builtin.TypeInfo.Struct{
            .layout = .Auto,
            .fields = &fields,
            .decls = &[_]std.builtin.TypeInfo.Declaration{},
            .is_tuple = false,
        },
    });
}

pub fn queryExtensions(comptime query: []const []const u8) QueryExtension(query) {
    var exts = std.mem.zeroes(QueryExtension(query));
    if (builtin.cpu.arch != .wasm32) {
        const extension_list = std.mem.span(zerog.gles.getString(zerog.gles.EXTENSIONS)) orelse return exts;
        var iterator = std.mem.split(u8, extension_list, " ");
        while (iterator.next()) |extension| {
            inline for (std.meta.fields(QueryExtension(query))) |fld| {
                if (std.mem.eql(u8, extension, "GL_" ++ fld.name)) {
                    @field(exts, fld.name) = true;
                }
            }
        }
    }
    return exts;
}

pub fn queryExtension(comptime name: []const u8) bool {
    return @field(queryExtensions(&[_][]const u8{name}), name);
}

pub fn enableDebugOutput() !void {
    if (!queryExtension("KHR_debug"))
        return error.DebugExtensionNotFound;

    const debug = zerog.gles.GL_KHR_debug;
    try debug.load({}, zerog.loadOpenGlFunction);

    debug.debugMessageCallbackKHR(glesDebugProc, null);
    zerog.gles.enable(debug.DEBUG_OUTPUT_KHR);
}

fn glesDebugProc(
    source: zerog.gles.GLenum,
    msg_type: zerog.gles.GLenum,
    id: zerog.gles.GLuint,
    severity: zerog.gles.GLenum,
    length: zerog.gles.GLsizei,
    message_ptr: [*:0]const u8,
    userParam: ?*c_void,
) callconv(.C) void {
    _ = msg_type;
    _ = userParam;
    _ = id;
    // This callback is only used when the extension is available
    const debug = zerog.gles.GL_KHR_debug;

    const source_name = switch (source) {
        debug.DEBUG_SOURCE_API_KHR => "api",
        debug.DEBUG_SOURCE_WINDOW_SYSTEM_KHR => "window system",
        debug.DEBUG_SOURCE_SHADER_COMPILER_KHR => "shader compiler",
        debug.DEBUG_SOURCE_THIRD_PARTY_KHR => "third party",
        debug.DEBUG_SOURCE_APPLICATION_KHR => "application",
        debug.DEBUG_SOURCE_OTHER_KHR => "other",
        else => "unknown",
    };

    const type_name = switch (msg_type) {
        debug.DEBUG_TYPE_ERROR_KHR => "error",
        debug.DEBUG_TYPE_DEPRECATED_BEHAVIOR_KHR => "deprecated behavior",
        debug.DEBUG_TYPE_UNDEFINED_BEHAVIOR_KHR => "undefined behavior",
        debug.DEBUG_TYPE_PORTABILITY_KHR => "portability",
        debug.DEBUG_TYPE_PERFORMANCE_KHR => "performance",
        debug.DEBUG_TYPE_OTHER_KHR => "other",
        debug.DEBUG_TYPE_MARKER_KHR => "marker",
        debug.DEBUG_TYPE_PUSH_GROUP_KHR => "push group",
        debug.DEBUG_TYPE_POP_GROUP_KHR => "pop group",
        else => "unknown",
    };
    const message = message_ptr[0..@intCast(usize, length)];

    const fmt_string = "[{s}] [{s}] {s}";
    var fmt_arg = .{ source_name, type_name, message };

    switch (severity) {
        debug.DEBUG_SEVERITY_HIGH_KHR => logger.emerg(fmt_string, fmt_arg),
        debug.DEBUG_SEVERITY_MEDIUM_KHR => logger.err(fmt_string, fmt_arg),
        debug.DEBUG_SEVERITY_LOW_KHR => logger.warn(fmt_string, fmt_arg),
        debug.DEBUG_SEVERITY_NOTIFICATION_KHR => logger.info(fmt_string, fmt_arg),
        else => logger.emerg("encountered invalid log severity: {}", .{severity}),
    }
}
