const std = @import("std");
const gles = @import("../gl_es_2v0.zig");
const types = @import("../zero-graphics.zig");
const logger = std.log.scoped(.zerog_renderer2D);
const z3d = @import("z3d-format.zig");

const glesh = @import("gles-helper.zig");

const ResourcePool = @import("resource_pool.zig").ResourcePool;

const zigimg = @import("zigimg");

const Self = @This();

const Color = types.Color;
const Rectangle = types.Rectangle;
const Size = types.Size;
const Point = types.Point;
const Mat4 = [4][4]f32;

pub const DrawError = error{OutOfMemory};
pub const CreateTextureError = error{ OutOfMemory, GraphicsApiFailure };
pub const LoadTextureError = CreateTextureError || error{InvalidImageData};
pub const CreateGeometryError = error{ OutOfMemory, GraphicsApiFailure };
pub const LoadTextureFileError = LoadTextureError || error{FileNotFound};
pub const LoadGeometryError = CreateGeometryError || LoadTextureFileError || error{InvalidGeometryData};
pub const InitError = error{ OutOfMemory, GraphicsApiFailure };

fn makeMut(comptime T: type, ptr: *const T) *T {
    return @intToPtr(*T, @ptrToInt(ptr));
}

const TexturePool = ResourcePool(Texture, *Self, destroyTextureInternal);
const GeometryPool = ResourcePool(Geometry, *Self, destroyGeometryInternal);

/// Vertex attributes used in this renderer
const attributes = .{
    .vPosition = 0,
    .vNormal = 1,
    .vUV = 2,
};

static_geometry_shader: GeometryShader,

/// list of CCW triangles that will be rendered 
draw_calls: std.ArrayList(DrawCall),

allocator: *std.mem.Allocator,

textures: TexturePool,
geometries: GeometryPool,

white_texture: *const Texture,

pub fn init(allocator: *std.mem.Allocator) InitError!Self {
    const static_vertex_source =
        \\attribute vec3 vPosition;
        \\attribute vec3 vNormal;
        \\attribute vec2 vUV;
        \\uniform mat4 uWorldMatrix;
        \\uniform mat4 uViewProjMatrix;
        \\varying vec2 aUV;
        \\varying vec3 aNormal;
        \\void main()
        \\{
        \\   gl_Position = uViewProjMatrix * uWorldMatrix * vec4(vPosition, 1.0);
        \\   aNormal = mat3(uWorldMatrix) * normalize(vNormal);
        \\   aUV = vUV;
        \\}
    ;
    const static_alphatest_fragment_source =
        \\precision mediump float;
        \\varying vec2 aUV;
        \\varying vec3 aNormal;
        \\uniform sampler2D uTexture;
        \\void main()
        \\{
        \\   vec3 light_color_a = vec3(0.86, 0.77, 0.38); // 0xdcc663
        \\   vec3 light_color_b = vec3(0.25, 0.44, 0.43); // 0x40716f
        \\   vec3 light_dir_a = normalize(vec3(-0.3, -0.4, -0.1));
        \\   vec3 light_dir_b = normalize(vec3(0.1, 1.0, 0.2));
        \\   float light_val_a = clamp(-dot(aNormal, light_dir_a), 0.0, 1.0);
        \\   float light_val_b = clamp(-dot(aNormal, light_dir_b), 0.0, 1.0);
        \\   vec3 lighting = light_color_a * light_val_a + light_color_b * light_val_b;
        \\   gl_FragColor = texture2D(uTexture, aUV);
        \\   if(gl_FragColor.a < 0.5)
        \\     discard;
        \\   gl_FragColor.rgb *= lighting;
        \\}
    ;

    var static_geometry_shader = try GeometryShader.create(static_vertex_source, static_alphatest_fragment_source);
    errdefer static_geometry_shader.destroy();

    var self = Self{
        .allocator = allocator,

        .static_geometry_shader = static_geometry_shader,

        .textures = TexturePool.init(allocator),
        .geometries = GeometryPool.init(allocator),

        .draw_calls = std.ArrayList(DrawCall).init(allocator),
        .white_texture = undefined,
    };

    self.white_texture = try self.createTexture(2, 2, &([1]u8{0xFF} ** 16));

    return self;
}

pub fn deinit(self: *Self) void {
    self.geometries.deinit(self);
    self.textures.deinit(self);
    self.static_geometry_shader.destroy();
    self.draw_calls.deinit();
    self.* = undefined;
}

const GeometryShader = struct {
    const Uniforms = struct {
        // vertex shader
        uWorldMatrix: gles.GLint,
        uViewProjMatrix: gles.GLint,

        // fragment shader
        uTexture: gles.GLint,
    };

    program: gles.GLuint,
    uniforms: Uniforms,

    pub fn create(vertex_source: []const u8, fragment_source: []const u8) !GeometryShader {
        const shader_program = try glesh.compileShaderProgram(attributes, vertex_source, fragment_source);
        errdefer gles.deleteProgram(shader_program);

        return GeometryShader{
            .program = shader_program,
            .uniforms = glesh.fetchUniforms(shader_program, Uniforms),
        };
    }

    pub fn destroy(self: *GeometryShader) void {
        gles.deleteProgram(self.program);
        self.* = undefined;
    }
};

/// Creates a new texture for this renderer with the size `width`×`height`.
/// The texture is only valid as long as the renderer is valid *or* `destroyTexture` is called,
/// whichever happens first.
/// If `initial_data` is given, the data is encoded as BGRA pixels.
pub fn createTexture(self: *Self, width: u15, height: u15, initial_data: ?[]const u8) CreateTextureError!*const Texture {
    var id: gles.GLuint = undefined;
    gles.genTextures(1, &id);
    if (id == 0)
        return error.GraphicsApiFailure;

    gles.bindTexture(gles.TEXTURE_2D, id);
    if (initial_data) |data| {
        std.debug.assert(data.len == 4 * @as(usize, width) * @as(usize, height));
        gles.texImage2D(gles.TEXTURE_2D, 0, gles.RGBA, width, height, 0, gles.RGBA, gles.UNSIGNED_BYTE, data.ptr);
    } else {
        gles.texImage2D(gles.TEXTURE_2D, 0, gles.RGBA, width, height, 0, gles.RGBA, gles.UNSIGNED_BYTE, null);
    }
    gles.texParameteri(gles.TEXTURE_2D, gles.TEXTURE_MIN_FILTER, gles.LINEAR_MIPMAP_LINEAR);
    gles.texParameteri(gles.TEXTURE_2D, gles.TEXTURE_MAG_FILTER, gles.LINEAR);

    gles.texParameteri(gles.TEXTURE_2D, gles.TEXTURE_WRAP_S, gles.REPEAT);
    gles.texParameteri(gles.TEXTURE_2D, gles.TEXTURE_WRAP_T, gles.REPEAT);

    gles.generateMipmap(gles.TEXTURE_2D);

    return try self.textures.allocate(Texture{
        .handle = id,
        .width = width,
        .height = height,
    });
}

/// Loads a texture from the given `image_data`. It should contain the file data as it would
/// be on disk, encoded as PNG. Other file formats might be supported,
/// but only PNG has official support.
pub fn loadTexture(self: *Self, image_data: []const u8) LoadTextureError!*const Texture {
    var image = zigimg.image.Image.fromMemory(self.allocator, image_data) catch |err| {
        logger.debug("failed to load texture: {s}", .{@errorName(err)});
        return LoadTextureError.InvalidImageData;
    };
    defer image.deinit();

    var buffer = try self.allocator.alloc(u8, 4 * image.width * image.height);
    defer self.allocator.free(buffer);

    var i: usize = 0;
    var pixels = image.iterator();
    while (pixels.next()) |pix| {
        const p8 = pix.toIntegerColor8();
        buffer[4 * i + 0] = p8.R;
        buffer[4 * i + 1] = p8.G;
        buffer[4 * i + 2] = p8.B;
        buffer[4 * i + 3] = p8.A;
        i += 1;
    }
    std.debug.assert(i == image.width * image.height);

    return try self.createTexture(
        @intCast(u15, image.width),
        @intCast(u15, image.height),
        buffer,
    );
}

/// Destroys a texture and releases all of its memory.
/// The texture passed here must be created with `createTexture`.
pub fn destroyTexture(self: *Self, texture: *const Texture) void {
    self.textures.release(self, makeMut(Texture, texture));
}

fn destroyTextureInternal(self: *Self, tex: *Texture) void {
    _ = self;
    gles.deleteTextures(1, &tex.handle);
    tex.* = undefined;
}

/// Updates the texture data of the given texture.
/// `data` is encoded as BGRA pixels.
pub fn updateTexture(self: *Self, texture: *Texture, data: []const u8) void {
    _ = self;
    std.debug.assert(data.len == 4 * @as(usize, texture.width) * @as(usize, texture.height));
    gles.bindTexture(gles.TEXTURE_2D, texture.handle);
    gles.texImage2D(gles.TEXTURE_2D, 0, gles.RGBA, texture.width, texture.height, 0, gles.RGBA, gles.UNSIGNED_BYTE, data.ptr);
}

/// Creates a new drawable geometry.
/// - `vertices` is an array of model vertices.
/// - `indices` is a the full index buffer, where each three consecutive indices describe a triangle.
/// - `meshes` is a list of ranges into `indices` with each range associated with a texture to be drawn
pub fn createGeometry(self: *Self, vertices: []const Vertex, indices: []const u16, meshes: []const Mesh) CreateGeometryError!*const Geometry {
    for (indices) |idx| {
        std.debug.assert(idx < vertices.len);
    }

    const vertices_clone = try self.allocator.dupe(Vertex, vertices);
    errdefer self.allocator.free(vertices_clone);

    const indices_clone = try self.allocator.dupe(u16, indices);
    errdefer self.allocator.free(indices_clone);

    const meshes_clone = try self.allocator.dupe(Mesh, meshes);
    errdefer self.allocator.free(meshes_clone);

    var bufs: [2]gles.GLuint = undefined;
    gles.genBuffers(bufs.len, &bufs);
    errdefer gles.deleteBuffers(bufs.len, &bufs);

    var geom = Geometry{
        .vertex_buffer = bufs[0],
        .index_buffer = bufs[1],
        .vertices = vertices_clone,
        .indices = indices_clone,
        .meshes = meshes_clone,
    };

    gles.bindBuffer(gles.ARRAY_BUFFER, geom.vertex_buffer);
    gles.bufferData(gles.ARRAY_BUFFER, @intCast(gles.GLsizei, @sizeOf(Vertex) * geom.vertices.len), geom.vertices.ptr, gles.STATIC_DRAW);
    gles.bindBuffer(gles.ARRAY_BUFFER, 0);

    gles.bindBuffer(gles.ELEMENT_ARRAY_BUFFER, geom.index_buffer);
    gles.bufferData(gles.ELEMENT_ARRAY_BUFFER, @intCast(gles.GLsizei, @sizeOf(u16) * geom.indices.len), geom.indices.ptr, gles.STATIC_DRAW);
    gles.bindBuffer(gles.ELEMENT_ARRAY_BUFFER, 0);

    for (geom.meshes) |mesh| {
        if (mesh.texture) |tex| {
            self.textures.retain(makeMut(Texture, tex));
        }
    }

    return try self.geometries.allocate(geom);
}

/// Creates a simple drawable geometry.
/// - `vertices` is an array of model vertices.
/// - `indices` is a the full index buffer, where each three consecutive indices describe a triangle.
/// - `texture` is the texture the geometry is drawn with.
pub fn createMesh(self: *Self, vertices: []const Vertex, indices: []const u16, texture: ?*const Texture) CreateGeometryError!*const Geometry {
    return self.createGeometry(
        vertices,
        indices,
        &[_]Mesh{
            Mesh{ .offset = 0, .count = indices.len, .texture = texture },
        },
    );
}

pub fn loadGeometry(self: *Self, geometry_data: []const u8, loader_context: anytype, loadTextureFile: fn (*Self, @TypeOf(loader_context), name: []const u8) LoadTextureFileError!*const Texture) LoadGeometryError!*const Geometry {
    if (geometry_data.len < @sizeOf(z3d.CommonHeader))
        return error.InvalidGeometryData;

    const common_header = @ptrCast(*align(1) const z3d.CommonHeader, &geometry_data[0]);

    if (!std.mem.eql(u8, &common_header.magic, &z3d.magic_number))
        return error.InvalidGeometryData;
    if (std.mem.littleToNative(u16, common_header.version) != 1)
        return error.InvalidGeometryData;

    var loader_arena = std.heap.ArenaAllocator.init(self.allocator);
    defer loader_arena.deinit();

    const allocator = &loader_arena.allocator;

    switch (common_header.type) {
        .static => {
            const header = @ptrCast(*align(1) const z3d.static_model.Header, &geometry_data[0]);
            const vertex_count = std.mem.littleToNative(u32, header.vertex_count);
            const index_count = std.mem.littleToNative(u32, header.index_count);
            const mesh_count = std.mem.littleToNative(u32, header.mesh_count);
            if (vertex_count == 0)
                return error.InvalidGeometryData;
            if (index_count == 0)
                return error.InvalidGeometryData;
            if (mesh_count == 0)
                return error.InvalidGeometryData;

            const vertex_offset = 24;
            const index_offset = vertex_offset + 32 * vertex_count;
            const mesh_offset = index_offset + 2 * index_count;

            const src_vertices = @ptrCast([*]align(1) const z3d.static_model.Vertex, &geometry_data[vertex_offset]);
            const src_indices = @ptrCast([*]align(1) const z3d.static_model.Index, &geometry_data[index_offset]);
            const src_meshes = @ptrCast([*]align(1) const z3d.static_model.Mesh, &geometry_data[mesh_offset]);

            const dst_vertices = try allocator.alloc(Vertex, vertex_count);
            const dst_indices = try allocator.alloc(u16, index_count);
            const dst_meshes = try allocator.alloc(Mesh, mesh_count);

            for (dst_vertices) |*vtx, i| {
                const src = src_vertices[i];
                vtx.* = Vertex{
                    .x = src.x,
                    .y = src.y,
                    .z = src.z,
                    .nx = src.nx,
                    .ny = src.ny,
                    .nz = src.nz,
                    .u = src.u,
                    .v = src.v,
                };
            }
            for (dst_indices) |*idx, i| {
                idx.* = std.mem.littleToNative(u16, src_indices[i]);
            }

            for (dst_meshes) |*mesh, i| {
                const src_mesh = src_meshes[i];
                mesh.* = Mesh{
                    .offset = std.mem.littleToNative(u32, src_mesh.offset),
                    .count = std.mem.littleToNative(u32, src_mesh.length),
                    .texture = null,
                };

                const texture_file_len = std.mem.indexOfScalar(u8, &src_mesh.texture_file, 0) orelse src_mesh.texture_file.len;
                const texture_file = src_mesh.texture_file[0..texture_file_len];

                if (texture_file.len > 0) {
                    mesh.texture = try loadTextureFile(self, loader_context, texture_file);
                }
            }

            _ = loader_context;
            _ = loadTextureFile;

            return try self.createGeometry(
                dst_vertices,
                dst_indices,
                dst_meshes,
            );
        },
        .dynamic => @panic("dynamic model loading not supported yet!"),
        _ => return error.InvalidGeometryData,
    }
}

/// Destroys a previously created geometry. Do not use the pointer afterwards anymore. The geometry
/// must be created with `createMesh` or `createGeometry`.
pub fn destroyGeometry(self: *Self, geometry: *const Geometry) void {
    self.geometries.release(self, makeMut(Geometry, geometry));
}

fn destroyGeometryInternal(self: *Self, geometry: *Geometry) void {
    for (geometry.meshes) |mesh| {
        if (mesh.texture) |tex| {
            self.textures.release(self, makeMut(Texture, tex));
        }
    }

    self.allocator.free(geometry.indices);
    self.allocator.free(geometry.vertices);
    self.allocator.free(geometry.meshes);

    var bufs = [2]gles.GLuint{ geometry.vertex_buffer, geometry.index_buffer };
    gles.deleteBuffers(bufs.len, &bufs);
}

/// Resets the state of the renderer and prepares a fresh new frame.
pub fn reset(self: *Self) void {
    // release all geometries.
    for (self.draw_calls.items) |draw_call| {
        self.geometries.release(self, makeMut(Geometry, draw_call.geometry));
    }
    self.draw_calls.shrinkRetainingCapacity(0);
}

/// Draws the given `geometry` with the given world `transform`.
pub fn drawGeometry(self: *Self, geometry: *const Geometry, transform: Mat4) !void {
    const dc = try self.draw_calls.addOne();
    errdefer _ = self.draw_calls.pop(); // remove the draw call in case of error

    dc.* = DrawCall{
        .geometry = geometry,
        .transform = transform,
    };

    // we need to keep the geometry alive until someone calls `reset` on the renderer.
    // otherwise, we will have the problem that a temporary geometry will be freed before
    // we render it.
    self.geometries.retain(makeMut(Geometry, geometry));
}

/// Renders the currently contained data to the screen.
pub fn render(self: Self, viewProjectionMatrix: [4][4]f32) void {
    glesh.enableAttributes(attributes);
    defer glesh.disableAttributes(attributes);

    gles.enable(gles.DEPTH_TEST);
    gles.disable(gles.BLEND);

    gles.depthFunc(gles.LEQUAL);

    gles.useProgram(self.static_geometry_shader.program);
    gles.uniform1i(self.static_geometry_shader.uniforms.uTexture, 0);
    gles.uniformMatrix4fv(self.static_geometry_shader.uniforms.uViewProjMatrix, 1, gles.FALSE, @ptrCast([*]const f32, &viewProjectionMatrix));

    gles.activeTexture(gles.TEXTURE0);

    for (self.draw_calls.items) |draw_call| {
        draw_call.geometry.bind();

        gles.uniformMatrix4fv(self.static_geometry_shader.uniforms.uWorldMatrix, 1, gles.FALSE, @ptrCast([*]const f32, &draw_call.transform));

        for (draw_call.geometry.meshes) |mesh| {
            const tex_handle = mesh.texture orelse self.white_texture;

            gles.bindTexture(gles.TEXTURE_2D, tex_handle.handle);
            gles.drawElements(
                gles.TRIANGLES,
                @intCast(gles.GLsizei, mesh.count),
                gles.UNSIGNED_SHORT,
                @intToPtr(?*const c_void, @sizeOf(u16) * mesh.offset),
            );
        }
    }
}

pub const Vertex = extern struct {
    // coordinates in local space
    x: f32,
    y: f32,
    z: f32,

    // normal of the vertex in local space,
    // must have length = 1
    nx: f32,
    ny: f32,
    nz: f32,

    // normalized texture coordinates, 0…1
    u: f32,
    v: f32,

    pub fn init(pos: [3]f32, normal: [3]f32, uv: [2]f32) Vertex {
        return Vertex{
            .x = pos[0],
            .y = pos[1],
            .z = pos[2],
            .nx = normal[0],
            .ny = normal[1],
            .nz = normal[2],
            .u = uv[0],
            .v = uv[1],
        };
    }
};

pub const Texture = struct {
    /// private texture handle
    handle: gles.GLuint,

    /// width of the texture in pixels
    width: u15,

    /// height of the texture in pixels
    height: u15,
};

/// A group of faces in a `Geometry` that shares the same texture. Each
/// `Geometry` has at least one mesh.
pub const Mesh = struct {
    offset: usize,
    count: usize,
    texture: ?*const Texture,
};

/// A 3D model with one or more textures.
pub const Geometry = struct {
    vertex_buffer: gles.GLuint,
    index_buffer: gles.GLuint,

    vertices: []Vertex,
    indices: []u16,
    meshes: []Mesh,

    fn bind(self: Geometry) void {
        gles.bindBuffer(gles.ARRAY_BUFFER, self.vertex_buffer);
        gles.vertexAttribPointer(attributes.vPosition, 3, gles.FLOAT, gles.FALSE, @sizeOf(Vertex), @intToPtr(?*const c_void, @offsetOf(Vertex, "x")));
        gles.vertexAttribPointer(attributes.vNormal, 3, gles.FLOAT, gles.TRUE, @sizeOf(Vertex), @intToPtr(?*const c_void, @offsetOf(Vertex, "nx")));
        gles.vertexAttribPointer(attributes.vUV, 2, gles.FLOAT, gles.FALSE, @sizeOf(Vertex), @intToPtr(?*const c_void, @offsetOf(Vertex, "u")));
        gles.bindBuffer(gles.ELEMENT_ARRAY_BUFFER, self.index_buffer);
    }
};

const DrawCall = struct {
    transform: Mat4,
    geometry: *const Geometry,
};
