const std = @import("std");
const api = @import("api");
const z3d = @import("z3d");
const args_parser = @import("args");

const CliArgs = struct {
    output: ?[]const u8 = null,
    dynamic: bool = false,
    help: bool = false,
    @"test": bool = false,

    pub const shorthands = .{
        .o = "output",
        .h = "help",
        .d = "dynamic",
    };
};

fn printUsage(writer: anytype) !void {
    try writer.writeAll(
        \\mconv - convert 3d models to zero-graphics format
        \\
        \\Usage:
        \\  mconv [--help] [--output <file>] [--dynamic] [--test] <input file>
        \\  -h, --help           Prints this help and succeeds.
        \\  -o, --output <file>  Writes the file to <file>. Otherwise, the extension of the input file is changed to .z3d
        \\  -d, --dynamic        Converts the model as a dynamic model with skinning information. Those models are usually somewhat larger, but can be animated.
        \\      --test           Does not write the output file, but will still perform the model conversion. This can be used to check if a model is convertible.
        \\
    );
}

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub fn main() !u8 {
    defer _ = gpa.deinit();

    const allocator = &gpa.allocator;

    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    var cli = args_parser.parseForCurrentProcess(CliArgs, allocator, .print) catch return 1;
    defer cli.deinit();

    if (cli.options.help) {
        try printUsage(stdout);
        return 0;
    }
    if (cli.positionals.len != 1) {
        try printUsage(stderr);
        return 1;
    }

    const src_file = cli.positionals[0];

    var dst_file = std.ArrayList(u8).init(allocator);
    defer dst_file.deinit();

    if (cli.options.output) |dst| {
        try dst_file.appendSlice(dst);
    } else {
        try dst_file.appendSlice(src_file);
        const ext = std.fs.path.extension(src_file);
        dst_file.shrinkRetainingCapacity(dst_file.items.len - ext.len);
        try dst_file.appendSlice(".z3d");
    }

    var stream = Stream{
        .target_buffer = std.ArrayList(u8).init(allocator),
    };
    defer stream.target_buffer.deinit();

    if (!api.transformFile(src_file.ptr, &stream.mesh_stream, if (cli.options.dynamic) api.dynamic_geometry else api.static_geometry)) {
        return 1;
    }

    if (!cli.options.@"test") {
        try std.fs.cwd().writeFile(
            dst_file.items,
            stream.target_buffer.items,
        );
    }

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

        if (vertices == 0) return stream.setError(error.NoVertices);
        if (indices == 0) return stream.setError(error.NoFaces);
        if (ranges == 0) return stream.setError(error.NoMeshes);

        stream.vertex_count = vertices;
        stream.index_count = indices;
        stream.mesh_count = ranges;

        stream.vertex_offset = 0;
        stream.index_offset = 0;
        stream.mesh_offset = 0;

        stream.target_buffer.resize(stream.fileSize()) catch |err| return stream.setError(err);

        std.mem.set(u8, stream.target_buffer.items, 0x55); // set to "undefined"

        const header = @ptrCast(*align(1) z3d.static_model.Header, &stream.target_buffer.items[0]);
        header.* = z3d.static_model.Header{
            .common = z3d.CommonHeader{ .type = .static },
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

        const vertices = @ptrCast([*]align(1) z3d.static_model.Vertex, &stream.target_buffer.items[stream.vertexOffset()]);
        vertices[stream.vertex_offset] = z3d.static_model.Vertex{
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

        const indices = @ptrCast([*]align(1) z3d.static_model.Index, &stream.target_buffer.items[stream.indexOffset()]);
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

        const texture_file = if (texture) |tex_str| std.mem.sliceTo(tex_str, 0) else null;
        if (texture_file != null and texture_file.?.len > 120)
            return stream.setError(error.FileNameTooLong);

        const meshes = @ptrCast([*]align(1) z3d.static_model.Mesh, &stream.target_buffer.items[stream.meshOffset()]);
        meshes[stream.mesh_offset] = z3d.static_model.Mesh{
            .offset = std.mem.nativeToLittle(u32, std.math.cast(u32, offset) catch |e| return stream.setError(e)),
            .length = std.mem.nativeToLittle(u32, std.math.cast(u32, length) catch |e| return stream.setError(e)),
            .texture_file = [1]u8{0} ** 120,
        };

        if (texture_file) |file_name| {
            std.mem.copy(
                u8,
                &meshes[stream.mesh_offset].texture_file,
                file_name,
            );
        }

        stream.mesh_offset += 1;

        // std.log.info("[{} {} \"{s}\"]", .{ offset, count, std.mem.sliceTo(texture.?, 0) });
    }
};
