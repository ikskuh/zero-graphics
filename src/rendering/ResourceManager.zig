//! A resource manager that is required by the different renderers.
//! This provides textures, geometries, animations, ... for the use over several
//! different renderers.
const std = @import("std");
const zigimg = @import("zigimg");
const zero_graphics = @import("../zero-graphics.zig");

const gl = zero_graphics.gles;

const Renderer2D = @import("Renderer2D.zig");
const Renderer3D = @import("Renderer3D.zig");
const RendererSky = @import("RendererSky.zig");

const ResourcePool = @import("resource_pool.zig").ResourcePool;
const TexturePool = ResourcePool(Texture, *ResourceManager, destroyTextureInternal);
const ShaderPool = ResourcePool(Shader, *ResourceManager, destroyShaderInternal);
const BufferPool = ResourcePool(Buffer, *ResourceManager, destroyBufferInternal);
const GeometryPool = ResourcePool(Geometry, *ResourceManager, destroyGeometryInternal);
const EnvMapPool = ResourcePool(EnvironmentMap, *ResourceManager, destroyEnvironmentMapInternal);
const ResourceManager = @This();

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

allocator: *std.mem.Allocator,

textures: TexturePool,
shaders: ShaderPool,
buffers: BufferPool,
geometries: GeometryPool,
envmaps: EnvMapPool,

is_gpu_available: bool,

pub fn init(allocator: *std.mem.Allocator) ResourceManager {
    return ResourceManager{
        .allocator = allocator,
        .textures = TexturePool.init(allocator),
        .shaders = ShaderPool.init(allocator),
        .buffers = BufferPool.init(allocator),
        .geometries = GeometryPool.init(allocator),
        .envmaps = EnvMapPool.init(allocator),
        .is_gpu_available = false,
    };
}

pub fn deinit(self: *ResourceManager) void {
    if (self.is_gpu_available) {
        self.destroyGpuData();
    }
    self.envmaps.deinit(self);
    self.geometries.deinit(self);
    self.buffers.deinit(self);
    self.shaders.deinit(self);
    self.textures.deinit(self);
    self.* = undefined;
}

fn initGpu(self: *ResourceManager, pool: anytype) !void {
    var it = pool.list.first;
    while (it) |node| : (it = node.next) {
        const item = &node.data.resource;
        try item.initGpu(self);
    }
}

pub fn initializeGpuData(self: *ResourceManager) !void {
    std.debug.assert(self.is_gpu_available == false);
    self.is_gpu_available = true;

    try self.initGpu(&self.textures);
    try self.initGpu(&self.shaders);
    try self.initGpu(&self.buffers);
    try self.initGpu(&self.geometries);
    try self.initGpu(&self.envmaps);
}

fn destroyGpu(self: *ResourceManager, pool: anytype) void {
    _ = self;
    var it = pool.list.first;
    while (it) |node| : (it = node.next) {
        const item = &node.data.resource;
        item.destroyGpu(self);
    }
}

pub fn destroyGpuData(self: *ResourceManager) void {
    std.debug.assert(self.is_gpu_available == true);
    self.is_gpu_available = false;

    self.destroyGpu(&self.textures);
    self.destroyGpu(&self.shaders);
    self.destroyGpu(&self.buffers);
    self.destroyGpu(&self.geometries);
    self.destroyGpu(&self.envmaps);
}

pub fn createRenderer2D(self: *ResourceManager) !Renderer2D {
    return try Renderer2D.init(self, self.allocator);
}

pub fn createRenderer3D(self: *ResourceManager) !Renderer3D {
    return try Renderer3D.init(self, self.allocator);
}

pub fn createRendererSky(self: *ResourceManager) !RendererSky {
    return try RendererSky.init(self, self.allocator);
}

const ResourceDataHandle = struct {
    const TypeID = if (@import("builtin").mode == .Debug)
        usize
    else
        u0;

    fn typeId(comptime T: type) TypeID {
        _ = T;
        if (@import("builtin").mode == .Debug) {
            return @ptrToInt(&struct {
                var unique: u8 = 0;
            }.unique);
        }
        return 0;
    }

    type_id: TypeID,
    pointer: usize,

    pub fn createFrom(ptr: anytype) ResourceDataHandle {
        const P = @TypeOf(ptr);
        const T = std.meta.Child(P);
        var safe_ptr: *T = ptr;
        return ResourceDataHandle{
            .type_id = typeId(T),
            .pointer = @ptrToInt(safe_ptr),
        };
    }

    pub fn convertTo(self: ResourceDataHandle, comptime T: type) *T {
        std.debug.assert(self.type_id == typeId(T));
        return @intToPtr(*T, self.pointer);
    }
};

pub const CreateResourceDataError = error{ OutOfMemory, InvalidFormat, IoError, FileNotFound };

fn CreateResourceData(comptime ResourceData: type) type {
    return fn (ResourceDataHandle, *ResourceManager) CreateResourceDataError!ResourceData;
}

const DestroyResourceData = fn (ResourceDataHandle, *ResourceManager) void;

fn DataSource(comptime ResourceData: type) type {
    return struct {
        const Self = @This();

        pub fn init(allocator: *std.mem.Allocator, resource_data: anytype) !Self {
            const ActualDataType = @TypeOf(resource_data);

            const resource_data_cpy = try allocator.create(ActualDataType);
            errdefer allocator.destroy(resource_data_cpy);

            resource_data_cpy.* = resource_data;

            const Wrapper = struct {
                fn create(handle: ResourceDataHandle, rm: *ResourceManager) CreateResourceDataError!ResourceData {
                    // std.log.debug("create {s}", .{@typeName(ActualDataType)});
                    return try handle.convertTo(ActualDataType).create(rm);
                }
                fn destroy(handle: ResourceDataHandle, rm: *ResourceManager) void {
                    // std.log.debug("destroy {s}", .{@typeName(ActualDataType)});
                    rm.allocator.destroy(handle.convertTo(ActualDataType));
                }
            };

            return Self{
                .pointer = ResourceDataHandle.createFrom(resource_data_cpy),
                .create_data = Wrapper.create,
                .destroy_data = Wrapper.destroy,
            };
        }

        pub fn create(self: Self, rm: *ResourceManager) CreateResourceDataError!ResourceData {
            return self.create_data(self.pointer, rm) catch |err| {
                if (@errorReturnTrace()) |trace| std.debug.dumpStackTrace(trace.*);
                std.log.debug("failed to create resource {s}: {s}", .{ @typeName(ResourceData), @errorName(err) });
                return err;
            };
        }

        pub fn deinit(self: *Self, rm: *ResourceManager) void {
            self.destroy_data(self.pointer, rm);
            self.* = undefined;
        }

        pointer: ResourceDataHandle,
        create_data: CreateResourceData(ResourceData),
        destroy_data: DestroyResourceData,
    };
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Textures

pub const TextureData = struct {
    width: u15,
    height: u15,
    pixels: ?[]u8,

    pub fn deinit(self: TextureData, rm: *ResourceManager) void {
        if (self.pixels) |pixels| {
            rm.allocator.free(pixels);
        }
    }
};

pub const Texture = struct {
    pub const UsageHint = enum {
        ui,
        @"3d",
    };

    fn computePixelSize(width: u15, height: u15) usize {
        return @as(usize, width) * @as(usize, height);
    }

    fn computeByteSize(width: u15, height: u15) usize {
        return 4 * computePixelSize(width, height);
    }

    /// private texture handle
    instance: ?gl.GLuint,

    usage_hint: UsageHint,

    // width of the texture in pixels
    width: u15,

    // height of the texture in pixels
    height: u15,

    source: DataSource(TextureData),

    fn initGpuFromData(tex: *Texture, texture_data: TextureData) void {
        var id: gl.GLuint = undefined;
        gl.genTextures(1, &id);
        std.debug.assert(id != 0);

        gl.bindTexture(gl.TEXTURE_2D, id);
        defer gl.bindTexture(gl.TEXTURE_2D, 0);
        if (texture_data.pixels) |data| {
            std.debug.assert(data.len == computeByteSize(texture_data.width, texture_data.height));
            gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, texture_data.width, texture_data.height, 0, gl.RGBA, gl.UNSIGNED_BYTE, data.ptr);
        } else {
            gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, texture_data.width, texture_data.height, 0, gl.RGBA, gl.UNSIGNED_BYTE, null);
        }

        switch (tex.usage_hint) {
            .@"3d" => {
                gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
                gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

                gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
                gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);

                gl.generateMipmap(gl.TEXTURE_2D);
            },
            .ui => {
                gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
                gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

                gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
                gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
            },
        }

        tex.instance = id;
    }

    fn initGpu(tex: *Texture, rm: *ResourceManager) !void {
        std.debug.assert(tex.instance == null);

        var texture_data = try tex.source.create(rm);
        defer texture_data.deinit(rm);

        initGpuFromData(tex, texture_data);
    }

    fn destroyGpu(tex: *Texture, rm: *ResourceManager) void {
        std.debug.assert(tex.instance != null);
        _ = rm;
        gl.deleteTextures(1, &tex.instance.?);
        tex.instance = null;
    }
};

pub fn createTexture(self: *ResourceManager, usage_hint: Texture.UsageHint, resource_data: anytype) !*Texture {
    var source = try DataSource(TextureData).init(self.allocator, resource_data);
    errdefer source.deinit(self);

    // We need to create the texture data anyway, as we want to know how big our texture will be
    var texture_data = try source.create(self);
    defer texture_data.deinit(self);

    const texture = Texture{
        .instance = null,
        .usage_hint = usage_hint,

        .width = texture_data.width,
        .height = texture_data.height,

        .source = source,
    };

    const texture_ptr = try self.textures.allocate(texture);
    errdefer self.textures.release(self, texture_ptr);

    if (self.is_gpu_available) {
        texture_ptr.initGpuFromData(texture_data);
    }

    return texture_ptr;
}

/// Updates the texture data of the given texture.
/// `data` is encoded as BGRA pixels.
pub fn updateTexture(self: *ResourceManager, texture: *Texture, data: []const u8) void {
    _ = self;
    std.debug.assert(data.len == Texture.computeByteSize(texture.width, texture.height));
    gl.bindTexture(gl.TEXTURE_2D, texture.handle);
    defer gl.bindTexture(gl.TEXTURE_2D, 0);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, texture.width, texture.height, 0, gl.RGBA, gl.UNSIGNED_BYTE, data.ptr);
}

pub fn retainTexture(self: *ResourceManager, texture: *Texture) void {
    self.textures.retain(texture);
}

/// Destroys a texture and releases all of its memory.
/// The texture passed here must be created with `createTexture`.
pub fn destroyTexture(self: *ResourceManager, texture: *Texture) void {
    self.textures.release(self, texture);
}

fn destroyTextureInternal(ctx: *ResourceManager, tex: *Texture) void {
    if (ctx.is_gpu_available) {
        tex.destroyGpu(ctx);
    }
    tex.source.deinit(ctx);
    tex.* = undefined;
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Textures

pub const EnvironmentMapSide = enum(gl.GLenum) {
    x_plus = gl.TEXTURE_CUBE_MAP_POSITIVE_X,
    y_plus = gl.TEXTURE_CUBE_MAP_POSITIVE_Y,
    z_plus = gl.TEXTURE_CUBE_MAP_POSITIVE_Z,
    x_minus = gl.TEXTURE_CUBE_MAP_NEGATIVE_X,
    y_minus = gl.TEXTURE_CUBE_MAP_NEGATIVE_Y,
    z_minus = gl.TEXTURE_CUBE_MAP_NEGATIVE_Z,
};

pub const EnvironmentMapData = struct {
    const Sides = std.EnumArray(EnvironmentMapSide, []u8);

    arena: std.heap.ArenaAllocator,
    width: u15,
    height: u15,
    sides: Sides,

    pub fn deinit(self: *EnvironmentMapData, rm: *ResourceManager) void {
        for (self.sides.values) |val| {
            rm.allocator.free(val);
        }
        self.* = undefined;
    }
};

pub const EnvironmentMap = struct {
    fn computePixelSize(width: u15, height: u15) usize {
        return @as(usize, width) * @as(usize, height);
    }

    fn computeByteSize(width: u15, height: u15) usize {
        return 4 * computePixelSize(width, height);
    }

    /// private texture handle
    instance: ?gl.GLuint,

    // width of the environment map in pixels
    width: u15,

    // height of the environment map in pixels
    height: u15,

    source: DataSource(EnvironmentMapData),

    fn initGpuFromData(tex: *EnvironmentMap, env_data: EnvironmentMapData) void {
        var id: gl.GLuint = undefined;
        gl.genTextures(1, &id);
        std.debug.assert(id != 0);

        gl.bindTexture(gl.TEXTURE_CUBE_MAP, id);
        defer gl.bindTexture(gl.TEXTURE_CUBE_MAP, 0);

        {
            for (env_data.sides.values) |buffer, i| {
                const key = EnvironmentMapData.Sides.Indexer.keyForIndex(i);

                std.debug.assert(buffer.len == computeByteSize(env_data.width, env_data.height));
                gl.texImage2D(@enumToInt(key), 0, gl.RGBA, env_data.width, env_data.height, 0, gl.RGBA, gl.UNSIGNED_BYTE, buffer.ptr);
            }
        }

        gl.texParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
        gl.texParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

        gl.texParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_S, gl.REPEAT);
        gl.texParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_T, gl.REPEAT);

        gl.generateMipmap(gl.TEXTURE_CUBE_MAP);

        tex.instance = id;
    }

    fn initGpu(tex: *EnvironmentMap, rm: *ResourceManager) !void {
        std.debug.assert(tex.instance == null);

        var texture_data = try tex.source.create(rm);
        defer texture_data.deinit(rm);

        initGpuFromData(tex, texture_data);
    }

    fn destroyGpu(tex: *EnvironmentMap, rm: *ResourceManager) void {
        std.debug.assert(tex.instance != null);
        _ = rm;
        gl.deleteTextures(1, &tex.instance.?);
        tex.instance = null;
    }
};

pub fn createEnvironmentMap(self: *ResourceManager, resource_data: anytype) !*EnvironmentMap {
    var source = try DataSource(EnvironmentMapData).init(self.allocator, resource_data);
    errdefer source.deinit(self);

    // We need to create the texture data anyway, as we want to know how big our texture will be
    var envmap_data = try source.create(self);
    defer envmap_data.deinit(self);

    const env_map = EnvironmentMap{
        .instance = null,

        .width = envmap_data.width,
        .height = envmap_data.height,

        .source = source,
    };

    const env_map_ptr = try self.envmaps.allocate(env_map);
    errdefer self.envmaps.release(self, env_map_ptr);

    if (self.is_gpu_available) {
        env_map_ptr.initGpuFromData(envmap_data);
    }

    return env_map_ptr;
}

pub fn retainEnvironmentMap(self: *ResourceManager, envmap: *EnvironmentMap) void {
    self.envmaps.retain(envmap);
}

/// Destroys a texture and releases all of its memory.
/// The texture passed here must be created with `createTexture`.
pub fn destroyEnvironmentMap(self: *ResourceManager, envmap: *EnvironmentMap) void {
    self.envmaps.release(self, envmap);
}

fn destroyEnvironmentMapInternal(ctx: *ResourceManager, envmap: *EnvironmentMap) void {
    if (ctx.is_gpu_available) {
        envmap.destroyGpu(ctx);
    }
    envmap.source.deinit(ctx);
    envmap.* = undefined;
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Shaders

pub const ShaderData = struct {
    pub fn init(allocator: *std.mem.Allocator) ShaderData {
        return ShaderData{
            .arena = std.heap.ArenaAllocator.init(allocator),
            .sources = std.ArrayList(Source).init(allocator),
            .attributes = std.ArrayList(ShaderAttribute).init(allocator),
        };
    }

    pub fn deinit(self: *@This()) void {
        self.sources.deinit();
        self.arena.deinit();
        self.* = undefined;
    }

    pub fn appendShader(self: *@This(), shader_type: gl.GLenum, source: []const u8) !void {
        try self.sources.append(Source{
            .shader_type = shader_type,
            .source = try self.arena.allocator.dupeZ(u8, source),
        });
    }

    pub fn setAttribute(self: *@This(), name: []const u8, index: gl.GLuint) !void {
        try self.attributes.append(ShaderAttribute{
            .name = try self.arena.allocator.dupeZ(u8, name),
            .index = index,
        });
    }

    arena: std.heap.ArenaAllocator,
    sources: std.ArrayList(Source),
    attributes: std.ArrayList(ShaderAttribute),

    const Source = struct {
        source: [:0]const u8,
        shader_type: gl.GLenum,
    };
};

pub const Shader = struct {
    instance: ?gl.GLuint,

    source: DataSource(ShaderData),

    fn initGpu(shader: *Shader, rm: *ResourceManager) !void {
        var data = try shader.source.create(rm);
        defer data.deinit();

        var shaders = try rm.allocator.alloc(gl.GLuint, data.sources.items.len);
        defer rm.allocator.free(shaders);

        var index: usize = 0;
        errdefer for (shaders[0..index]) |sh| {
            gl.deleteShader(sh);
        };

        while (index < shaders.len) : (index += 1) {
            shaders[index] = zero_graphics.gles_utils.createAndCompileShader(data.sources.items[index].shader_type, data.sources.items[index].source) catch return error.InvalidFormat;
        }

        const program = gl.createProgram();

        for (data.attributes.items) |attrib| {
            gl.bindAttribLocation(program, attrib.index, attrib.name.ptr);
        }

        for (shaders) |sh| {
            gl.attachShader(program, sh);
        }
        defer for (shaders) |sh| {
            gl.detachShader(program, sh);
        };

        gl.linkProgram(program);

        var status: gl.GLint = undefined;
        gl.getProgramiv(program, gl.LINK_STATUS, &status);
        if (status != gl.TRUE)
            return error.InvalidFormat;

        shader.instance = program;
    }

    fn destroyGpu(shader: *Shader, rm: *ResourceManager) void {
        _ = rm;
        std.debug.assert(shader.instance != null);
        gl.deleteProgram(shader.instance.?);
        shader.instance = null;
    }
};

pub fn createShader(self: *ResourceManager, resource_data: anytype) !*Shader {
    var source = try DataSource(ShaderData).init(self.allocator, resource_data);
    errdefer source.deinit(self);

    const shader = try self.shaders.allocate(Shader{
        .instance = null,
        .source = source,
    });
    errdefer self.shaders.release(self, shader);

    if (self.is_gpu_available) {
        try shader.initGpu(self);
    }

    return shader;
}

pub fn destroyShader(self: *ResourceManager, shader: *Shader) void {
    self.shaders.release(self, shader);
}

fn destroyShaderInternal(ctx: *ResourceManager, shader: *Shader) void {
    if (ctx.is_gpu_available) {
        shader.destroyGpu(ctx);
    }
    shader.source.deinit(ctx);
    shader.* = undefined;
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Buffers

pub const BufferData = struct {
    data: ?[]const u8,

    pub fn deinit(self: *@This(), allocator: *std.mem.Allocator) void {
        if (self.data) |data| {
            allocator.free(data);
        }
        self.* = undefined;
    }
};

pub const Buffer = struct {
    instance: ?gl.GLuint,

    source: DataSource(BufferData),

    fn initGpu(buffer: *Buffer, rm: *ResourceManager) !void {
        std.debug.assert(buffer.instance == null);

        var data = try buffer.source.create(rm);
        defer data.deinit(rm.allocator);

        var instance: gl.GLuint = 0;
        gl.genBuffers(1, &instance);
        std.debug.assert(instance != 0);

        if (data.data != null) @panic("Initializing predefined buffers is not implemented yet!");

        buffer.instance = instance;
    }
    fn destroyGpu(buffer: *Buffer, rm: *ResourceManager) void {
        _ = rm;
        std.debug.assert(buffer.instance != null);
        gl.deleteBuffers(1, &buffer.instance.?);
        buffer.instance = null;
    }
};

pub fn createBuffer(self: *ResourceManager, resource_data: anytype) !*Buffer {
    var source = try DataSource(BufferData).init(self.allocator, resource_data);
    errdefer source.deinit(self);

    const buffer = try self.buffers.allocate(Buffer{
        .instance = null,
        .source = source,
    });
    errdefer self.buffers.release(self, buffer);

    if (self.is_gpu_available) {
        try buffer.initGpu(self);
    }

    return buffer;
}

pub fn destroyBuffer(self: *ResourceManager, buffer: *Buffer) void {
    self.buffers.release(self, buffer);
}

fn destroyBufferInternal(ctx: *ResourceManager, buffer: *Buffer) void {
    if (ctx.is_gpu_available) {
        buffer.destroyGpu(ctx);
    }
    buffer.source.deinit(ctx);
    buffer.* = undefined;
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Geometries

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

/// A group of faces in a `Geometry` that shares the same texture. Each
/// `Geometry` has at least one mesh.
pub const Mesh = struct {
    offset: usize,
    count: usize,
    texture: ?*Texture,
};

pub const GeometryData = struct {
    vertices: []Vertex,
    indices: []u16,
    meshes: []Mesh,

    pub fn deinit(self: *@This(), rm: *ResourceManager) void {
        rm.allocator.free(self.vertices);
        rm.allocator.free(self.indices);
        rm.allocator.free(self.meshes);
        self.* = undefined;
    }
};

/// A 3D model with one or more textures.
pub const Geometry = struct {
    vertex_buffer: ?gl.GLuint,
    index_buffer: ?gl.GLuint,

    meshes: ?[]Mesh,

    source: DataSource(GeometryData),

    fn initGpu(geometry: *Geometry, rm: *ResourceManager) !void {
        std.debug.assert(geometry.vertex_buffer == null);
        std.debug.assert(geometry.index_buffer == null);
        std.debug.assert(geometry.meshes == null);

        var data = try geometry.source.create(rm);
        defer data.deinit(rm);

        const meshes = try rm.allocator.dupe(Mesh, data.meshes);
        errdefer rm.allocator.free(meshes);

        for (meshes) |mesh| {
            if (mesh.texture) |texture| {
                rm.retainTexture(texture);
            }
        }

        var bufs: [2]gl.GLuint = undefined;
        gl.genBuffers(bufs.len, &bufs);
        errdefer gl.deleteBuffers(bufs.len, &bufs);

        gl.bindBuffer(gl.ARRAY_BUFFER, bufs[0]);
        gl.bufferData(gl.ARRAY_BUFFER, @intCast(gl.GLsizei, @sizeOf(Vertex) * data.vertices.len), data.vertices.ptr, gl.STATIC_DRAW);
        gl.bindBuffer(gl.ARRAY_BUFFER, 0);

        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, bufs[1]);
        gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, @intCast(gl.GLsizei, @sizeOf(u16) * data.indices.len), data.indices.ptr, gl.STATIC_DRAW);
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0);

        geometry.vertex_buffer = bufs[0];
        geometry.index_buffer = bufs[1];
        geometry.meshes = meshes;
    }

    fn destroyGpu(geometry: *Geometry, rm: *ResourceManager) void {
        std.debug.assert(geometry.vertex_buffer != null);
        std.debug.assert(geometry.index_buffer != null);
        std.debug.assert(geometry.meshes != null);

        var bufs = [2]gl.GLuint{ geometry.vertex_buffer.?, geometry.index_buffer.? };
        gl.deleteBuffers(bufs.len, &bufs);

        if (geometry.meshes) |meshes| {
            for (meshes) |mesh| {
                if (mesh.texture) |texture| {
                    rm.destroyTexture(texture);
                }
            }
            rm.allocator.free(meshes);
        }

        geometry.vertex_buffer = null;
        geometry.index_buffer = null;
        geometry.meshes = null;
    }
};

pub fn createGeometry(self: *ResourceManager, data_source: anytype) !*Geometry {
    var source = try DataSource(GeometryData).init(self.allocator, data_source);
    errdefer source.deinit(self);

    const geometry = try self.geometries.allocate(Geometry{
        .vertex_buffer = null,
        .index_buffer = null,
        .meshes = null,
        .source = source,
    });
    errdefer self.geometries.release(self, geometry);

    if (self.is_gpu_available) {
        try geometry.initGpu(self);
    }

    return geometry;
}

pub fn retainGeometry(self: *ResourceManager, geometry: *Geometry) void {
    self.geometries.retain(geometry);
}

/// Destroys a previously created geometry. Do not use the pointer afterwards anymore. The geometry
/// must be created with `createMesh` or `createGeometry`.
pub fn destroyGeometry(self: *ResourceManager, geometry: *Geometry) void {
    self.geometries.release(self, geometry);
}

fn destroyGeometryInternal(ctx: *ResourceManager, geometry: *Geometry) void {
    if (ctx.is_gpu_available) {
        geometry.destroyGpu(ctx);
    }
    geometry.source.deinit(ctx);
    geometry.* = undefined;
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Builtin loaders

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Builtin geometry loaders

pub const StaticMesh = struct {
    vertices: []const Vertex,
    indices: []const u16,
    texture: ?*Texture,

    pub fn create(self: @This(), rm: *ResourceManager) CreateResourceDataError!GeometryData {
        const vertices = try rm.allocator.dupe(Vertex, self.vertices);
        errdefer rm.allocator.free(vertices);
        const indices = try rm.allocator.dupe(u16, self.indices);
        errdefer rm.allocator.free(indices);

        const meshes = try rm.allocator.alloc(Mesh, 1);
        errdefer rm.allocator.free(meshes);

        meshes[0] = Mesh{
            .offset = 0,
            .count = indices.len,
            .texture = self.texture,
        };

        return GeometryData{
            .vertices = vertices,
            .indices = indices,
            .meshes = meshes,
        };
    }
};

pub const StaticGeometry = struct {
    vertices: []const Vertex,
    indices: []const u16,
    meshes: []const Mesh,

    pub fn create(self: @This(), rm: *ResourceManager) CreateResourceDataError!GeometryData {
        const vertices = try rm.allocator.dupe(Vertex, self.vertices);
        errdefer rm.allocator.free(vertices);
        const indices = try rm.allocator.dupe(u16, self.indices);
        errdefer rm.allocator.free(indices);
        const meshes = try rm.allocator.dupe(Mesh, self.meshes);
        errdefer rm.allocator.free(meshes);

        return GeometryData{
            .vertices = vertices,
            .indices = indices,
            .meshes = meshes,
        };
    }
};

pub fn Z3DGeometry(comptime TextureLoader: ?type) type {
    const ActualTextureLoader = TextureLoader orelse struct {};
    if (TextureLoader) |Loader| {
        if (!@hasDecl(Loader, "load"))
            @compileError(@typeName(Loader) ++ " requires a pub fn load()!");
    }
    return struct {
        const z3d = @import("z3d-format.zig");

        data: []const u8,
        loader: ?ActualTextureLoader = null,

        pub fn create(self: @This(), rm: *ResourceManager) CreateResourceDataError!GeometryData {
            const geometry_data = self.data;

            if (geometry_data.len < @sizeOf(z3d.CommonHeader))
                return error.InvalidFormat;

            const common_header = @ptrCast(*align(1) const z3d.CommonHeader, &geometry_data[0]);

            if (!std.mem.eql(u8, &common_header.magic, &z3d.magic_number))
                return error.InvalidFormat;
            if (std.mem.littleToNative(u16, common_header.version) != 1)
                return error.InvalidFormat;

            var loader_arena = std.heap.ArenaAllocator.init(rm.allocator);
            defer loader_arena.deinit();

            switch (common_header.type) {
                .static => {
                    const header = @ptrCast(*align(1) const z3d.static_model.Header, &geometry_data[0]);
                    const vertex_count = std.mem.littleToNative(u32, header.vertex_count);
                    const index_count = std.mem.littleToNative(u32, header.index_count);
                    const mesh_count = std.mem.littleToNative(u32, header.mesh_count);
                    if (vertex_count == 0)
                        return error.InvalidFormat;
                    if (index_count == 0)
                        return error.InvalidFormat;
                    if (mesh_count == 0)
                        return error.InvalidFormat;

                    const vertex_offset = 24;
                    const index_offset = vertex_offset + 32 * vertex_count;
                    const mesh_offset = index_offset + 2 * index_count;

                    const src_vertices = @ptrCast([*]align(1) const z3d.static_model.Vertex, &geometry_data[vertex_offset]);
                    const src_indices = @ptrCast([*]align(1) const z3d.static_model.Index, &geometry_data[index_offset]);
                    const src_meshes = @ptrCast([*]align(1) const z3d.static_model.Mesh, &geometry_data[mesh_offset]);

                    const dst_vertices = try rm.allocator.alloc(Vertex, vertex_count);
                    errdefer rm.allocator.free(dst_vertices);
                    const dst_indices = try rm.allocator.alloc(u16, index_count);
                    errdefer rm.allocator.free(dst_indices);
                    const dst_meshes = try rm.allocator.alloc(Mesh, mesh_count);
                    errdefer rm.allocator.free(dst_meshes);

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
                            if (comptime TextureLoader != null) {
                                if (self.loader) |loader| {
                                    mesh.texture = try loader.load(rm, texture_file);
                                    //
                                } else {
                                    std.log.warn("Z3D file contains textures, but no texture loader was given. The texture '{s}' is missing.", .{texture_file});
                                }
                            } else {
                                std.log.warn("Z3D file contains textures, but the texture loader cannot load textures. The texture '{s}' is missing.", .{texture_file});
                            }
                        }
                    }

                    return GeometryData{
                        .vertices = dst_vertices,
                        .indices = dst_indices,
                        .meshes = dst_meshes,
                    };
                },
                .dynamic => @panic("dynamic model loading not supported yet!"),
                _ => return error.InvalidFormat,
            }
        }
    };
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Builtin buffer loaders

pub const EmptyBuffer = struct {
    dummy: u1 = 0,
    pub fn create(self: @This(), rm: *ResourceManager) CreateResourceDataError!BufferData {
        _ = self;
        _ = rm;
        return BufferData{ .data = null };
    }
};

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Builtin shader loaders

pub const ShaderAttribute = zero_graphics.gles_utils.Attribute;

pub const BasicShader = struct {
    vertex_shader: []const u8,
    fragment_shader: []const u8,
    attributes: []const ShaderAttribute,

    pub fn create(self: @This(), rm: *ResourceManager) CreateResourceDataError!ShaderData {
        var shader = ShaderData.init(rm.allocator);
        errdefer shader.deinit();

        try shader.appendShader(gl.VERTEX_SHADER, self.vertex_shader);
        try shader.appendShader(gl.FRAGMENT_SHADER, self.fragment_shader);

        for (self.attributes) |attrib| {
            try shader.setAttribute(attrib.name, attrib.index);
        }

        return shader;
    }
};

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Builtin texture loaders

pub const UninitializedTexture = struct {
    width: u15,
    height: u15,

    pub fn create(self: @This(), rm: *ResourceManager) CreateResourceDataError!TextureData {
        _ = rm;
        return TextureData{
            .width = self.width,
            .height = self.height,
            .pixels = null,
        };
    }
};

pub const FlatTexture = struct {
    const Color = struct { r: u8, g: u8, b: u8, a: u8 = 0xFF };

    width: u15,
    height: u15,
    color: Color,

    pub fn create(self: @This(), rm: *ResourceManager) CreateResourceDataError!TextureData {
        const buffer = try rm.allocator.alloc(u8, Texture.computeByteSize(self.width, self.height));
        errdefer rm.allocator.free(buffer);

        var i: usize = 0;
        while (i < buffer.len) : (i += 4) {
            buffer[i + 0] = self.color.r;
            buffer[i + 1] = self.color.g;
            buffer[i + 2] = self.color.b;
            buffer[i + 3] = self.color.a;
        }

        return TextureData{
            .width = self.width,
            .height = self.height,
            .pixels = buffer,
        };
    }
};

pub const RawRgbaTexture = struct {
    width: u15,
    height: u15,
    pixels: []const u8,

    pub fn create(self: @This(), rm: *ResourceManager) CreateResourceDataError!TextureData {
        return TextureData{
            .width = self.width,
            .height = self.height,
            .pixels = try rm.allocator.dupe(u8, self.pixels),
        };
    }
};

pub const DecodePng = struct {
    data: []const u8,
    flip_y: bool = false,

    pub fn create(self: @This(), rm: *ResourceManager) CreateResourceDataError!TextureData {
        var image = zigimg.image.Image.fromMemory(rm.allocator, self.data) catch {
            // logger.debug("failed to load texture: {s}", .{@errorName(err)});
            return error.InvalidFormat;
        };
        defer image.deinit();

        var buffer = try rm.allocator.alloc(u8, 4 * image.width * image.height);
        errdefer rm.allocator.free(buffer);

        var x: usize = 0;
        var y: usize = if (self.flip_y) image.height - 1 else 0;
        var pixels = image.iterator();
        while (pixels.next()) |pix| {
            const p8 = pix.toIntegerColor8();

            const offset = image.width * y + x;

            buffer[4 * offset + 0] = p8.R;
            buffer[4 * offset + 1] = p8.G;
            buffer[4 * offset + 2] = p8.B;
            buffer[4 * offset + 3] = p8.A;

            x += 1;
            if (x >= image.width) {
                x = 0;
                if (self.flip_y) {
                    if (y > 0) y -= 1;
                } else {
                    y += 1;
                }
            }
        }
        // std.debug.assert(i == image.width * image.height);

        return TextureData{
            .width = @intCast(u15, image.width),
            .height = @intCast(u15, image.height),
            .pixels = buffer,
        };
    }
};

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Builtin environment map loaders

pub const DecodeCompoundPng = struct {
    data: []const u8,

    const offsets = [6]EnvironmentMapSide{
        .x_minus, // 0
        .z_plus, // 1
        .x_plus, // 2
        .z_minus, // 3
        .y_minus, // 4
        .y_plus, // 5
    };

    pub fn create(self: @This(), rm: *ResourceManager) CreateResourceDataError!EnvironmentMapData {
        var image = zigimg.image.Image.fromMemory(rm.allocator, self.data) catch {
            // logger.debug("failed to load texture: {s}", .{@errorName(err)});
            return error.InvalidFormat;
        };
        defer image.deinit();

        std.debug.assert(image.width == 6 * image.height);

        var data = EnvironmentMapData{
            .arena = std.heap.ArenaAllocator.init(rm.allocator),
            .width = @intCast(u15, image.height),
            .height = @intCast(u15, image.height),
            .sides = EnvironmentMapData.Sides.initUndefined(),
        };
        errdefer data.deinit(rm);

        for (data.sides.values) |*val| {
            val.* = try rm.allocator.alloc(u8, Texture.computeByteSize(data.width, data.height));
        }

        var x: usize = 0;
        var y: usize = 0;
        var side: usize = 0;
        var pixels = image.iterator();
        while (pixels.next()) |pix| {
            // iterates row-major, with all 6 rows of each side first,
            // then all the next columns

            const p8 = pix.toIntegerColor8();
            const dst_buf = data.sides.get(offsets[side]);

            const offset = y * data.width + x;
            dst_buf[4 * offset + 0] = p8.R;
            dst_buf[4 * offset + 1] = p8.G;
            dst_buf[4 * offset + 2] = p8.B;
            dst_buf[4 * offset + 3] = p8.A;

            x += 1;
            if (x >= data.width) {
                x = 0;
                side += 1;
                if (side >= offsets.len) {
                    side = 0;
                    y += 1;
                }
            }
        }
        std.debug.assert(x == 0);
        std.debug.assert(y == image.height);
        std.debug.assert(side == 0);

        return data;
    }
};
