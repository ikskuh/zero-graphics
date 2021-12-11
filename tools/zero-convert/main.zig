//!
//! zero-convert model --dynamic --output=/tmp/meshes.z3d /game/foo/bar.fbx
//! zero-convert texture --output /tmp/graphic.ztex /game/foo/bam.png
//! zero-convert sound --output /tmp/foo.zsnd /game/foo/bam.ogg
//! zero-convert music --output /tmp/foo.zmus /bla/blub/tmp.ogg
//! zero-convert animation --output /tmp/foo.zani /bla/blub/tmp.fbx
//!

const std = @import("std");
const api = @import("api");
const z3d = @import("z3d");
const args_parser = @import("args");

const CliArgs = struct {
    output: ?[]const u8 = null,
    help: bool = false,
    @"test": bool = false,

    pub const shorthands = .{
        .o = "output",
        .h = "help",
    };
};

const ModelArgs = struct {
    dynamic: bool = false,

    pub const shorthands = .{
        .d = "dynamic",
    };
};

const Verbs = union(enum) {
    help: struct {},
    model: ModelArgs,
    texture: struct {},
    sound: struct {},
    music: struct {},
    animation: struct {},
};

fn printUsage(exe_name: []const u8, writer: anytype) !void {
    try writer.print("{s}", .{std.fs.path.basename(exe_name)});
    try writer.writeAll(
        \\ - convert assets into the zero-graphics format
        \\
        \\Usage:
        \\
    );
    try writer.print("  {s}", .{std.fs.path.basename(exe_name)});
    try writer.writeAll(
        \\ <verb> [--help] [--output <file>] [--test] <input file>
        \\  -h, --help           Prints this help and succeeds.
        \\  -o, --output <file>  Writes the file to <file>. Otherwise, the extension of the input file is changed to the right extension and will be placed next to the input file.
        \\      --test           Does not write the output file, but will still perform the conversion. This can be used to check if a file is convertible.
        \\
        \\Verbs:
        \\  model [--dynamic]
        \\    Converts a 3D model into the z3d format.
        \\    -d, --dynamic        Converts the model as a dynamic model with skinning information. Those models are usually somewhat larger, but can be animated.
        \\
        \\  texture
        \\    Converts a texture/image file into the ztex format.
        \\    
        \\  sound
        \\    Converts a short sound file into the zsnd format.
        \\    
        \\  music
        \\    Converts a long sound file into the zmus format.
        \\    
        \\  animation
        \\    Converts the animations from a 3D model into the zani format.
        \\
    );
}

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub fn main() !u8 {
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    var cli = args_parser.parseWithVerbForCurrentProcess(CliArgs, Verbs, allocator, .print) catch return 1;
    defer cli.deinit();

    if (cli.options.help or (cli.verb != null and cli.verb.? == .help)) {
        try printUsage(cli.executable_name.?, stdout);
        return 0;
    }
    if (cli.verb == null or cli.positionals.len != 1) {
        try printUsage(cli.executable_name.?, stderr);
        return 1;
    }

    const src_file_name = cli.positionals[0];

    const extension = switch (cli.verb.?) {
        .help => unreachable, // we already printed the help text
        .model => ".z3d",
        .texture => ".ztex",
        .sound => ".zsnd",
        .music => ".zmus",
        .animation => ".zani",
    };

    var dst_file = std.ArrayList(u8).init(allocator);
    defer dst_file.deinit();

    if (cli.options.output) |dst| {
        try dst_file.appendSlice(dst);
    } else {
        try dst_file.appendSlice(src_file_name);
        const ext = std.fs.path.extension(src_file_name);
        dst_file.shrinkRetainingCapacity(dst_file.items.len - ext.len);
        try dst_file.appendSlice(extension);
    }

    var final_buffer = std.ArrayList(u8).init(allocator);
    defer final_buffer.deinit();

    switch (cli.verb.?) {
        .model => |flags| {
            var stream = MeshStream{
                .target_buffer = &final_buffer,
            };

            if (!api.transformFile(src_file_name.ptr, &stream.mesh_stream, if (flags.dynamic) api.dynamic_geometry else api.static_geometry)) {
                return 1;
            }
        },
        else => {
            try stderr.print("{s} conversion is not implemented yet!\n", .{std.meta.tagName(cli.verb.?)});
            return 1;
        },
    }

    if (!cli.options.@"test") {
        try std.fs.cwd().writeFile(dst_file.items, final_buffer.items);
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

const MeshStream = struct {
    mesh_stream: api.MeshStream = .{
        .writeStaticHeader = writeStaticHeader,
        .writeVertex = writeVertex,
        .writeFace = writeFace,
        .writeMeshRange = writeMeshRange,
    },

    failed: ?anyerror = null,
    target_buffer: *std.ArrayList(u8),

    vertex_count: usize = 0,
    index_count: usize = 0,
    mesh_count: usize = 0,

    vertex_offset: usize = 0,
    index_offset: usize = 0,
    mesh_offset: usize = 0,

    fn setError(self: *MeshStream, err: anyerror) void {
        self.failed = err;
    }

    fn vertexOffset(self: MeshStream) usize {
        _ = self;
        return 24;
    }

    fn indexOffset(self: MeshStream) usize {
        return self.vertexOffset() + 32 * self.vertex_count;
    }

    fn meshOffset(self: MeshStream) usize {
        return self.indexOffset() + 2 * self.index_count;
    }

    fn fileSize(self: MeshStream) usize {
        return self.meshOffset() + 128 * self.mesh_count;
    }

    fn writeStaticHeader(mesh_stream: ?*api.MeshStream, vertices: usize, indices: usize, ranges: usize) callconv(.C) void {
        const stream = @fieldParentPtr(MeshStream, "mesh_stream", mesh_stream.?);
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
        const stream = @fieldParentPtr(MeshStream, "mesh_stream", mesh_stream.?);
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
        const stream = @fieldParentPtr(MeshStream, "mesh_stream", mesh_stream.?);
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
        const stream = @fieldParentPtr(MeshStream, "mesh_stream", mesh_stream.?);
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
