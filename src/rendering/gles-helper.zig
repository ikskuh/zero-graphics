const std = @import("std");
const builtin = @import("builtin");

const gles = @import("../gl_es_2v0.zig");
const zero_graphics = @import("../zero-graphics.zig");
const logger = std.log.scoped(.zerog_gles_helper);

fn QueryExtension(comptime query: []const []const u8) type {
    var fields: [query.len]std.builtin.Type.StructField = undefined;
    for (fields) |*fld, i| {
        fld.* = std.builtin.Type.StructField{
            .name = query[i],
            .type = bool,
            .default_value = &false,
            .is_comptime = false,
            .alignment = @alignOf(bool),
        };
    }
    return @Type(.{
        .Struct = std.builtin.Type.Struct{
            .layout = .Auto,
            .fields = &fields,
            .decls = &[_]std.builtin.Type.Declaration{},
            .is_tuple = false,
        },
    });
}

pub fn queryExtensions(comptime query: []const []const u8) QueryExtension(query) {
    var exts = std.mem.zeroes(QueryExtension(query));
    if (builtin.cpu.arch != .wasm32) {
        const extension_list = std.mem.span(zero_graphics.gles.getString(zero_graphics.gles.EXTENSIONS)) orelse return exts;
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

    const debug = zero_graphics.gles.GL_KHR_debug;
    try debug.load({}, zero_graphics.loadOpenGlFunction);

    debug.debugMessageCallbackKHR(glesDebugProc, null);
    zero_graphics.gles.enable(debug.DEBUG_OUTPUT_KHR);
}

fn glesDebugProc(
    source: zero_graphics.gles.GLenum,
    msg_type: zero_graphics.gles.GLenum,
    id: zero_graphics.gles.GLuint,
    severity: zero_graphics.gles.GLenum,
    length: zero_graphics.gles.GLsizei,
    message_ptr: [*:0]const u8,
    userParam: ?*anyopaque,
) callconv(.C) void {
    _ = userParam;
    _ = id;
    // This callback is only used when the extension is available
    const debug = zero_graphics.gles.GL_KHR_debug;

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
        debug.DEBUG_SEVERITY_HIGH_KHR => logger.err(fmt_string, fmt_arg),
        debug.DEBUG_SEVERITY_MEDIUM_KHR => logger.err(fmt_string, fmt_arg),
        debug.DEBUG_SEVERITY_LOW_KHR => logger.warn(fmt_string, fmt_arg),
        debug.DEBUG_SEVERITY_NOTIFICATION_KHR => logger.info(fmt_string, fmt_arg),
        else => logger.err("encountered invalid log severity: {}", .{severity}),
    }
}

pub fn fetchUniforms(program: gles.GLuint, comptime T: type) T {
    var t: T = undefined;
    inline for (std.meta.fields(T)) |fld| {
        const name = comptime fld.name[0.. :0];
        @field(t, fld.name) = gles.getUniformLocation(program, name);
    }
    return t;
}

pub fn enableAttributes(attribs: anytype) void {
    enableAttributesSlice(attributes(attribs));
}

/// Enables all attributes from the given attribute set
/// - `attributes`: A tuple of name-index values for the different vertex attributes
pub fn enableAttributesSlice(attribs: []const Attribute) void {
    for (attribs) |attr| {
        gles.enableVertexAttribArray(attr.index);
    }
}

pub fn disableAttributes(attribs: anytype) void {
    disableAttributesSlice(attributes(attribs));
}

/// Disables all attributes from the given attribute set
/// - `attributes`: A tuple of name-index values for the different vertex attributes
pub fn disableAttributesSlice(attribs: []const Attribute) void {
    for (attribs) |attr| {
        gles.disableVertexAttribArray(attr.index);
    }
}

/// A shader attribute.
pub const Attribute = struct {
    name: [:0]const u8,
    index: gles.GLuint,
};

/// Computes a list of attributes from a anonymous tuple in the form of
/// ```
/// attributes(.{
///   position:  0,
///   normal:    1,
///   tex_coord: 2,
/// });
/// ```
pub fn attributes(comptime list: anytype) []const Attribute {
    const T = @TypeOf(list);
    const fields = std.meta.fields(T);

    comptime var items: [fields.len]Attribute = undefined;
    comptime {
        inline for (fields) |attrib, i| {
            items[i] = Attribute{
                .name = attrib.name[0.. :0],
                .index = @field(list, attrib.name),
            };
        }
    }
    return &items;
}

/// - `attributes`: A tuple of name-index values for the different vertex attributes
/// - `vertex_source`: GLSL vertex shader source code
/// - `fragment_source`: GLSL fragment shader source code
pub fn compileShaderProgram(comptime attribs: anytype, vertex_source: []const u8, fragment_source: []const u8) !gles.GLuint {
    return compileShaderProgramSlice(attributes(attribs), vertex_source, fragment_source);
}

pub fn compileShaderProgramSlice(attribs: []const Attribute, vertex_source: []const u8, fragment_source: []const u8) !gles.GLuint {
    // Create and compile vertex shader
    const vertex_shader = createAndCompileShader(gles.VERTEX_SHADER, vertex_source) catch return error.GraphicsApiFailure;
    defer gles.deleteShader(vertex_shader);

    const fragment_shader = createAndCompileShader(gles.FRAGMENT_SHADER, fragment_source) catch return error.GraphicsApiFailure;
    defer gles.deleteShader(fragment_shader);

    const program = gles.createProgram();

    for (attribs) |attrib| {
        gles.bindAttribLocation(program, attrib.index, attrib.name.ptr);
    }

    gles.attachShader(program, vertex_shader);
    defer gles.detachShader(program, vertex_shader);

    gles.attachShader(program, fragment_shader);
    defer gles.detachShader(program, fragment_shader);

    gles.linkProgram(program);

    var status: gles.GLint = undefined;
    gles.getProgramiv(program, gles.LINK_STATUS, &status);
    if (status != gles.TRUE)
        return error.GraphicsApiFailure;

    return program;
}

/// Compiles a shader of type `shader_type` with the given GLSL `source` code.
pub fn createAndCompileShader(shader_type: gles.GLenum, source: []const u8) !gles.GLuint {
    return try createAndCompileShaderSources(shader_type, &[_][]const u8{source});
}

/// Compiles a shader of type `shader_type` with the given GLSL `source` code.
pub fn createAndCompileShaderSources(shader_type: gles.GLenum, sources: []const []const u8) !gles.GLuint {
    const max_sources = 32;

    var shader_ptrs: [max_sources][*]const u8 = undefined;
    var shader_lens: [max_sources]gles.GLint = undefined;

    for (sources) |source, i| {
        shader_ptrs[i] = source.ptr;
        shader_lens[i] = @intCast(gles.GLint, source.len);
    }

    // Create and compile vertex shader
    const shader = gles.createShader(shader_type);
    errdefer gles.deleteShader(shader);

    gles.shaderSource(shader, @intCast(gles.GLsizei, sources.len), &shader_ptrs, &shader_lens);
    gles.compileShader(shader);

    var status: gles.GLint = undefined;
    gles.getShaderiv(shader, gles.COMPILE_STATUS, &status);
    if (status != gles.TRUE)
        return error.FailedToCompileShader;

    return shader;
}
