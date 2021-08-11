const std = @import("std");

const gles = @import("../gl_es_2v0.zig");
const types = @import("../zero-graphics.zig");
const logger = std.log.scoped(.zerog_gles_helper);

pub fn fetchUniforms(program: gles.GLuint, comptime T: type) T {
    var t: T = undefined;
    inline for (std.meta.fields(T)) |fld| {
        const name = comptime fld.name[0.. :0];
        @field(t, fld.name) = gles.getUniformLocation(program, name.ptr);
    }
    return t;
}

/// Enables all attributes from the given attribute set
/// - `attributes`: A tuple of name-index values for the different vertex attributes
pub fn enableAttributes(comptime attributes: anytype) void {
    inline for (std.meta.fields(@TypeOf(attributes))) |attrib| {
        gles.enableVertexAttribArray(@field(attributes, attrib.name));
    }
}

/// Disables all attributes from the given attribute set
/// - `attributes`: A tuple of name-index values for the different vertex attributes
pub fn disableAttributes(comptime attributes: anytype) void {
    inline for (std.meta.fields(@TypeOf(attributes))) |attrib| {
        gles.disableVertexAttribArray(@field(attributes, attrib.name));
    }
}

/// - `attributes`: A tuple of name-index values for the different vertex attributes
/// - `vertex_source`: GLSL vertex shader source code
/// - `fragment_source`: GLSL fragment shader source code
pub fn compileShaderProgram(comptime attributes: anytype, vertex_source: []const u8, fragment_source: []const u8) !gles.GLuint {
    // Create and compile vertex shader
    const vertex_shader = createAndCompileShader(gles.VERTEX_SHADER, vertex_source) catch return error.GraphicsApiFailure;
    defer gles.deleteShader(vertex_shader);

    const fragment_shader = createAndCompileShader(gles.FRAGMENT_SHADER, fragment_source) catch return error.GraphicsApiFailure;
    defer gles.deleteShader(fragment_shader);

    const program = gles.createProgram();

    inline for (std.meta.fields(@TypeOf(attributes))) |attrib| {
        const name = comptime attrib.name[0.. :0];
        gles.bindAttribLocation(program, @field(attributes, attrib.name), name.ptr);
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
    const source_ptr = source.ptr;
    const source_len = @intCast(gles.GLint, source.len);

    // Create and compile vertex shader
    const shader = gles.createShader(shader_type);
    errdefer gles.deleteShader(shader);

    gles.shaderSource(
        shader,
        1,
        @ptrCast([*]const [*c]const u8, &source_ptr),
        @ptrCast([*]const gles.GLint, &source_len),
    );
    gles.compileShader(shader);

    var status: gles.GLint = undefined;
    gles.getShaderiv(shader, gles.COMPILE_STATUS, &status);
    if (status != gles.TRUE)
        return error.FailedToCompileShader;

    return shader;
}
