const std = @import("std");
const gles = @import("../gl_es_2v0.zig");
const types = @import("../zero-graphics.zig");
const logger = std.log.scoped(.zerog_renderer2D);

const glesh = @import("gles-helper.zig");

const ResourceManager = @import("ResourceManager.zig");
const ResourcePool = @import("resource_pool.zig").ResourcePool;

const zigimg = @import("zigimg");

const Self = @This();

const Mesh = ResourceManager.Mesh;
const Geometry = ResourceManager.Geometry;
const Texture = ResourceManager.Texture;
const Vertex = ResourceManager.Vertex;
const Color = types.Color;
const Rectangle = types.Rectangle;
const Size = types.Size;
const Point = types.Point;
const Mat4 = [4][4]f32;

pub const DrawError = error{OutOfMemory};
pub const InitError = ResourceManager.CreateResourceDataError || error{ OutOfMemory, GraphicsApiFailure };

/// Vertex attributes used in this renderer
const attributes = .{
    .vPosition = 0,
    .vNormal = 1,
    .vUV = 2,
};

static_geometry_shader: *ResourceManager.Shader,

/// list of CCW triangles that will be rendered 
draw_calls: std.ArrayList(DrawCall),

allocator: *std.mem.Allocator,

resources: *ResourceManager,

sky_cube: *ResourceManager.Geometry,

const sky_cube_mesh = ResourceManager.StaticMesh{
    .vertices = &[_]Vertex{
        .{ .x = -1, .y = -1, .z = -1, .nx = 0, .ny = 0, .nz = 0, .u = 0, .v = 0 },
        .{ .x = -1, .y = -1, .z = 1, .nx = 0, .ny = 0, .nz = 0, .u = 0, .v = 0 },
        .{ .x = -1, .y = 1, .z = -1, .nx = 0, .ny = 0, .nz = 0, .u = 0, .v = 0 },
        .{ .x = -1, .y = 1, .z = 1, .nx = 0, .ny = 0, .nz = 0, .u = 0, .v = 0 },
        .{ .x = 1, .y = -1, .z = -1, .nx = 0, .ny = 0, .nz = 0, .u = 0, .v = 0 },
        .{ .x = 1, .y = -1, .z = 1, .nx = 0, .ny = 0, .nz = 0, .u = 0, .v = 0 },
        .{ .x = 1, .y = 1, .z = -1, .nx = 0, .ny = 0, .nz = 0, .u = 0, .v = 0 },
        .{ .x = 1, .y = 1, .z = 1, .nx = 0, .ny = 0, .nz = 0, .u = 0, .v = 0 },
    },
    .indices = &[_]u16{
        0, 1, 3, 0, 3, 2, //
        4, 5, 1, 4, 1, 0, //
        6, 7, 5, 6, 5, 4, //
        2, 3, 7, 2, 7, 6, //
        1, 5, 7, 1, 7, 3, //
        0, 2, 4, 2, 6, 4, //
    },
    .texture = null,
};

pub fn init(resources: *ResourceManager, allocator: *std.mem.Allocator) InitError!Self {
    const static_vertex_source =
        \\attribute vec3 vPosition;
        \\uniform mat4 uViewProjMatrix;
        \\varying vec3 aPosition;
        \\void main()
        \\{
        \\   gl_Position = uViewProjMatrix * vec4(vPosition, 1.0);
        \\   aPosition = normalize(vPosition);
        \\}
    ;
    const static_alphatest_fragment_source =
        \\precision mediump float;
        \\varying vec3 aPosition;
        \\uniform samplerCube uTexture;
        \\void main()
        \\{
        \\   gl_FragColor = textureCube(uTexture, aPosition);
        \\}
    ;

    var static_geometry_shader = try resources.createShader(ResourceManager.BasicShader{
        .vertex_shader = static_vertex_source,
        .fragment_shader = static_alphatest_fragment_source,
        .attributes = glesh.attributes(attributes),
    });
    errdefer resources.destroyShader(static_geometry_shader);

    var self = Self{
        .allocator = allocator,
        .resources = resources,

        .static_geometry_shader = static_geometry_shader,

        .draw_calls = std.ArrayList(DrawCall).init(allocator),
        .sky_cube = undefined,
    };

    self.sky_cube = try self.resources.createGeometry(sky_cube_mesh);
    errdefer self.resources.destroyGeometry(self.sky_cube);

    return self;
}

pub fn deinit(self: *Self) void {
    self.reset();
    self.resources.destroyGeometry(self.sky_cube);
    self.resources.destroyShader(self.static_geometry_shader);
    self.draw_calls.deinit();
    self.* = undefined;
}

const Uniforms = struct {
    // vertex shader
    uViewProjMatrix: gles.GLint,

    // fragment shader
    uTexture: gles.GLint,
};

/// Resets the state of the renderer and prepares a fresh new frame.
pub fn reset(self: *Self) void {
    // release all geometries.
    for (self.draw_calls.items) |draw_call| {
        self.resources.destroyGeometry(draw_call.geometry);
    }
    self.draw_calls.shrinkRetainingCapacity(0);
}

fn bindGeometry(self: *const Geometry) void {
    gles.bindBuffer(gles.ARRAY_BUFFER, self.vertex_buffer.?);
    gles.vertexAttribPointer(attributes.vPosition, 3, gles.FLOAT, gles.FALSE, @sizeOf(Vertex), @intToPtr(?*const c_void, @offsetOf(Vertex, "x")));
    gles.vertexAttribPointer(attributes.vNormal, 3, gles.FLOAT, gles.TRUE, @sizeOf(Vertex), @intToPtr(?*const c_void, @offsetOf(Vertex, "nx")));
    gles.vertexAttribPointer(attributes.vUV, 2, gles.FLOAT, gles.FALSE, @sizeOf(Vertex), @intToPtr(?*const c_void, @offsetOf(Vertex, "u")));
    gles.bindBuffer(gles.ELEMENT_ARRAY_BUFFER, self.index_buffer.?);
}

/// Renders the currently contained data to the screen.
pub fn render(self: Self, sky_cube: *types.ResourceManager.EnvironmentMap, viewProjectionMatrix: [4][4]f32) void {
    glesh.enableAttributes(attributes);
    defer glesh.disableAttributes(attributes);

    gles.disable(gles.DEPTH_TEST);
    gles.disable(gles.BLEND);

    var uniforms = glesh.fetchUniforms(self.static_geometry_shader.instance.?, Uniforms);

    var untranslated_trafo = viewProjectionMatrix;

    gles.useProgram(self.static_geometry_shader.instance.?);
    gles.uniform1i(uniforms.uTexture, 0);
    gles.uniformMatrix4fv(uniforms.uViewProjMatrix, 1, gles.FALSE, @ptrCast([*]const f32, &untranslated_trafo));

    gles.activeTexture(gles.TEXTURE0);

    bindGeometry(self.sky_cube);

    gles.bindTexture(gles.TEXTURE_CUBE_MAP, sky_cube.instance.?);
    defer gles.bindTexture(gles.TEXTURE_CUBE_MAP, 0);

    for (self.sky_cube.meshes.?) |mesh| {
        gles.drawElements(
            gles.TRIANGLES,
            @intCast(gles.GLsizei, mesh.count),
            gles.UNSIGNED_SHORT,
            @intToPtr(?*const c_void, @sizeOf(u16) * mesh.offset),
        );
    }
}

const DrawCall = union(enum) {
    transform: Mat4,
    geometry: *Geometry,
};
