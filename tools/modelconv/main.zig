const std = @import("std");
const api = @import("api");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub fn main() !u8 {
    defer _ = gpa.deinit();

    const allocator = &gpa.allocator;

    const src_file = "/home/felix/projects/experiments/zero3d/vendor/zero-graphics/examples/data/twocubes.obj";
    const dst_file = "/home/felix/projects/experiments/zero3d/vendor/zero-graphics/examples/twocubes.z3d";

    var stream = Stream{
        .target_buffer = std.ArrayList(u8).init(allocator),
    };
    defer stream.target_buffer.deinit();

    if (!api.transformFile(src_file, &stream.mesh_stream, api.static_geometry)) {
        return 1;
    }

    try std.fs.cwd().writeFile(
        dst_file,
        stream.target_buffer.items,
    );

    return 0;
}

export fn printErrorMessage(text: [*]const u8, length: usize) void {
    std.log.err("{s}", .{text[0..length]});
}

export fn printInfoMessage(text: [*]const u8, length: usize) void {
    std.log.info("{s}", .{text[0..length]});
}

export fn printWarningMessage(text: [*]const u8, length: usize) void {
    std.log.warn("{s}", .{text[0..length]});
}

const Stream = struct {
    mesh_stream: api.MeshStream = .{
        .writeStaticHeader = writeStaticHeader,
        .writeVertex = writeVertex,
        .writeFace = writeFace,
        .writeMeshRange = writeMeshRange,
    },

    failed: ?anyerror = null,
    target_buffer: std.ArrayList(u8),

    vertex_count: usize = 0,
    index_count: usize = 0,
    mesh_count: usize = 0,

    vertex_offset: usize = 0,
    index_offset: usize = 0,
    mesh_offset: usize = 0,

    fn setError(self: *Stream, err: anyerror) void {
        self.failed = err;
    }

    fn vertexOffset(self: Stream) usize {
        _ = self;
        return 24;
    }

    fn indexOffset(self: Stream) usize {
        return self.vertexOffset() + 32 * self.vertex_count;
    }

    fn meshOffset(self: Stream) usize {
        return self.indexOffset() + 2 * self.index_count;
    }

    fn fileSize(self: Stream) usize {
        return self.meshOffset() + 128 * self.mesh_count;
    }

    fn writeStaticHeader(mesh_stream: ?*api.MeshStream, vertices: usize, indices: usize, ranges: usize) callconv(.C) void {
        const stream = @fieldParentPtr(Stream, "mesh_stream", mesh_stream.?);
        if (stream.failed != null)
            return;

        stream.vertex_count = vertices;
        stream.index_count = indices;
        stream.mesh_count = ranges;

        stream.vertex_offset = 0;
        stream.index_offset = 0;
        stream.mesh_offset = 0;

        stream.target_buffer.resize(stream.fileSize()) catch |err| return stream.setError(err);

        std.mem.set(u8, stream.target_buffer.items, 0x55); // set to "undefined"

        const header = @ptrCast(*align(1) static_model.Header, &stream.target_buffer.items[0]);
        header.* = static_model.Header{
            .common = CommonHeader{ .type = .static },
            .vertex_count = std.mem.nativeToLittle(u32, std.math.cast(u32, vertices) catch |err| return stream.setError(err)),
            .index_count = std.mem.nativeToLittle(u32, std.math.cast(u32, indices) catch |err| return stream.setError(err)),
            .mesh_count = std.mem.nativeToLittle(u32, std.math.cast(u32, ranges) catch |err| return stream.setError(err)),
        };

        //std.log.info("vertices: {},\tindices: {},\ttextures: {}", .{ vertices, indices, ranges });
    }

    fn writeVertex(mesh_stream: ?*api.MeshStream, x: f32, y: f32, z: f32, nx: f32, ny: f32, nz: f32, u: f32, v: f32) callconv(.C) void {
        const stream = @fieldParentPtr(Stream, "mesh_stream", mesh_stream.?);
        if (stream.failed != null)
            return;

        const vertices = @ptrCast([*]align(1) static_model.Vertex, &stream.target_buffer.items[stream.vertexOffset()]);
        vertices[stream.vertex_offset] = static_model.Vertex{
            .x = x,
            .y = y,
            .z = z,
            .nx = nx,
            .ny = ny,
            .nz = nz,
            .u = u,
            .v = v,
        };
        stream.vertex_offset += 1;

        // std.log.info("({d:.3} {d:.3} {d:.3}) ({d:.3} {d:.3} {d:.3}) ({d:.4} {d:.4})", .{ x, y, z, nx, ny, nz, u, v });
    }

    fn writeFace(mesh_stream: ?*api.MeshStream, index0: u16, index1: u16, index2: u16) callconv(.C) void {
        const stream = @fieldParentPtr(Stream, "mesh_stream", mesh_stream.?);
        if (stream.failed != null)
            return;

        const indices = @ptrCast([*]align(1) static_model.Index, &stream.target_buffer.items[stream.indexOffset()]);
        indices[stream.index_offset + 0] = index0;
        indices[stream.index_offset + 1] = index1;
        indices[stream.index_offset + 2] = index2;
        stream.index_offset += 3;
        // std.log.info("{{{} {} {}}}", .{ index0, index1, index2 });
    }

    fn writeMeshRange(mesh_stream: ?*api.MeshStream, offset: usize, length: usize, texture: ?[*:0]const u8) callconv(.C) void {
        const stream = @fieldParentPtr(Stream, "mesh_stream", mesh_stream.?);
        if (stream.failed != null)
            return;

        const texture_file = std.mem.sliceTo(texture.?, 0);
        if (texture_file.len > 120)
            return stream.setError(error.FileNameTooLong);

        const meshes = @ptrCast([*]align(1) static_model.Mesh, &stream.target_buffer.items[stream.meshOffset()]);
        meshes[stream.mesh_offset] = static_model.Mesh{
            .offset = std.mem.nativeToLittle(u32, std.math.cast(u32, offset) catch |e| return stream.setError(e)),
            .length = std.mem.nativeToLittle(u32, std.math.cast(u32, length) catch |e| return stream.setError(e)),
            .texture_file = [1]u8{0} ** 120,
        };

        std.mem.copy(
            u8,
            &meshes[stream.mesh_offset].texture_file,
            texture_file,
        );

        stream.mesh_offset += 1;

        // std.log.info("[{} {} \"{s}\"]", .{ offset, count, std.mem.sliceTo(texture.?, 0) });
    }

    const FileType = enum(u8) { static = 0, dynamic = 1 };

    const CommonHeader = extern struct {
        magic: [4]u8 = .{ 0xae, 0x32, 0x51, 0x1d },

        version: u16 = std.mem.nativeToLittle(u16, 1),
        type: FileType,
        _pad0: u8 = undefined,
    };

    const static_model = struct {
        comptime {
            if (@sizeOf(Header) != 24) @compileError("Header must have 24 byte!");
            if (@sizeOf(Vertex) != 32) @compileError("Vertex must have 32 byte!");
            if (@sizeOf(Index) != 2) @compileError("Index must have 2 byte!");
            if (@sizeOf(Mesh) != 128) @compileError("Mesh must have 128 byte!");
        }

        // size: 24
        const Header = extern struct {
            common: CommonHeader,
            vertex_count: u32,
            index_count: u32,
            mesh_count: u32,
            _pad1: u32 = undefined,
        };

        // size: 32
        const Vertex = extern struct {
            x: f32,
            y: f32,
            z: f32,
            nx: f32,
            ny: f32,
            nz: f32,
            u: f32,
            v: f32,
        };

        // size: 2
        const Index = u16;

        // size: 128
        const Mesh = extern struct {
            offset: u32,
            length: u32,
            texture_file: [120]u8, // NUL padded
        };
    };
};