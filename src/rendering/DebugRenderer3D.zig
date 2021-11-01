const std = @import("std");
const gl = @import("../gl_es_2v0.zig");
const types = @import("../zero-graphics.zig");
const logger = std.log.scoped(.zerog_renderer2D);

const glesh = @import("gles-helper.zig");

const c = @cImport({
    @cInclude("stb_truetype.h");
});

const zigimg = @import("zigimg");

const ResourceManager = @import("ResourceManager.zig");

const Self = @This();

const Color = types.Color;
const Rectangle = types.Rectangle;
const Size = types.Size;
const Point = types.Point;

const Vertex = types.ResourceManager.Vertex;

pub const Vec3 = [3]f32;
pub const Mat4 = [4][4]f32;

pub const DrawError = error{OutOfMemory};
pub const CreateFontError = error{ OutOfMemory, InvalidFontFile };
pub const InitError = error{ OutOfMemory, GraphicsApiFailure } || ResourceManager.CreateResourceDataError;

const Uniforms = struct {
    uViewProjMatrix: gl.GLint,
};

shader_program: *ResourceManager.Shader,

vertex_buffer: *ResourceManager.Buffer,

/// list of CCW triangles that will be rendered 
vertices: std.ArrayList(Vertex),
draw_calls: std.ArrayList(DrawCall),

allocator: *std.mem.Allocator,

resources: *ResourceManager,

pub fn init(resources: *ResourceManager, allocator: *std.mem.Allocator) InitError!Self {
    const vertex_source =
        \\attribute vec3 vPosition;
        \\attribute vec3 vNormal;
        \\attribute vec2 vUV;
        \\uniform mat4 uViewProjMatrix;
        \\varying vec4 aColor;
        \\void main()
        \\{
        \\  gl_Position = uViewProjMatrix * vec4(vPosition, 1.0);
        \\  aColor = vec4(vNormal, vUV.x);
        \\}
    ;
    const fragment_source =
        \\precision mediump float;
        \\varying vec4 aColor;
        \\void main()
        \\{
        \\  gl_FragColor = aColor;
        \\}
    ;

    const shader_program = try resources.createShader(ResourceManager.BasicShader{
        .vertex_shader = vertex_source,
        .fragment_shader = fragment_source,
        .attributes = glesh.attributes(types.ResourceManager.Geometry.attributes),
    });
    errdefer resources.destroyShader(shader_program);

    const vertex_buffer = try resources.createBuffer(ResourceManager.EmptyBuffer{});
    errdefer resources.destroyBuffer(vertex_buffer);

    var self = Self{
        .resources = resources,
        .shader_program = shader_program,
        .vertices = std.ArrayList(Vertex).init(allocator),
        .vertex_buffer = vertex_buffer,

        .allocator = allocator,
        .draw_calls = std.ArrayList(DrawCall).init(allocator),
    };

    return self;
}

pub fn deinit(self: *Self) void {
    self.reset();

    self.resources.destroyBuffer(self.vertex_buffer);
    self.resources.destroyShader(self.shader_program);
    self.draw_calls.deinit();
    self.vertices.deinit();
    self.* = undefined;
}

/// Resets the state of the renderer and prepares a fresh new frame.
pub fn reset(self: *Self) void {
    self.draw_calls.shrinkRetainingCapacity(0);
    self.vertices.shrinkRetainingCapacity(0);
}

/// Renders the currently contained data to the screen.
pub fn render(self: Self, viewProjectionMatrix: Mat4) void {
    glesh.enableAttributes(types.ResourceManager.Geometry.attributes);
    defer glesh.disableAttributes(types.ResourceManager.Geometry.attributes);

    gl.enable(gl.DEPTH_TEST);
    gl.disable(gl.BLEND);

    gl.bindBuffer(gl.ARRAY_BUFFER, self.vertex_buffer.instance.?);
    gl.bufferData(gl.ARRAY_BUFFER, @intCast(gl.GLsizeiptr, @sizeOf(Vertex) * self.vertices.items.len), self.vertices.items.ptr, gl.STATIC_DRAW);

    gl.vertexAttribPointer(types.ResourceManager.Geometry.attributes.vPosition, 3, gl.FLOAT, gl.FALSE, @sizeOf(Vertex), @intToPtr(?*const c_void, @offsetOf(Vertex, "x")));
    gl.vertexAttribPointer(types.ResourceManager.Geometry.attributes.vNormal, 3, gl.FLOAT, gl.TRUE, @sizeOf(Vertex), @intToPtr(?*const c_void, @offsetOf(Vertex, "nx")));
    gl.vertexAttribPointer(types.ResourceManager.Geometry.attributes.vUV, 2, gl.FLOAT, gl.FALSE, @sizeOf(Vertex), @intToPtr(?*const c_void, @offsetOf(Vertex, "u")));

    var uniforms = glesh.fetchUniforms(self.shader_program.instance.?, Uniforms);

    gl.useProgram(self.shader_program.instance.?);
    gl.uniformMatrix4fv(uniforms.uViewProjMatrix, 1, gl.FALSE, @ptrCast([*]const f32, &viewProjectionMatrix));

    for (self.draw_calls.items) |draw_call| {
        gl.drawArrays(
            draw_call.primitive_type,
            @intCast(gl.GLsizei, draw_call.offset),
            @intCast(gl.GLsizei, draw_call.count),
        );
    }
}

fn vertex(pos: Vec3, color: Color) Vertex {
    return Vertex{
        .x = pos[0],
        .y = pos[1],
        .z = pos[2],
        .u = @intToFloat(f32, color.a) / 255.0,
        .v = 0,
        .nx = @intToFloat(f32, color.r) / 255.0,
        .ny = @intToFloat(f32, color.g) / 255.0,
        .nz = @intToFloat(f32, color.b) / 255.0,
    };
}

fn beginDrawCall(self: Self, primitive_type: gl.GLenum) DrawCall {
    return DrawCall{
        .offset = self.vertices.items.len,
        .count = 0,
        .primitive_type = primitive_type,
    };
}

fn endDrawCall(self: *Self, dc: DrawCall) !void {
    var dc_copy = dc;
    dc_copy.count = self.vertices.items.len - dc.offset;
    if (dc_copy.count > 0) {
        // TODO: Implement draw call merging
        try self.draw_calls.append(dc_copy);
    }
}

fn resetDrawCall(self: *Self, dc: DrawCall) void {
    self.vertices.shrinkRetainingCapacity(dc.offset);
}

pub fn drawTriangle(self: *Self, v0: Vec3, v1: Vec3, v2: Vec3, color: Color) !void {
    var dc = self.beginDrawCall(gl.TRIANGLE_STRIP);
    errdefer self.resetDrawCall(dc);

    try self.vertices.append(vertex(v0, color));
    try self.vertices.append(vertex(v1, color));
    try self.vertices.append(vertex(v2, color));

    try self.endDrawCall(dc);
}

pub fn drawLine(self: *Self, v0: Vec3, v1: Vec3, color: Color) !void {
    var dc = self.beginDrawCall(gl.LINE_STRIP);
    errdefer self.resetDrawCall(dc);

    try self.vertices.append(vertex(v0, color));
    try self.vertices.append(vertex(v1, color));

    try self.endDrawCall(dc);
}

const DrawCall = struct {
    offset: usize,
    count: usize,
    primitive_type: gl.GLenum,
};
