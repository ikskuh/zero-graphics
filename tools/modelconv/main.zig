const std = @import("std");
const api = @import("api");

pub fn main() !u8 {
    const src_file = "/home/felix/projects/experiments/zero3d/vendor/zero-graphics/examples/data/twocubes.obj";
    //const dst_file = "/home/felix/projects/experiments/zero3d/vendor/zero-graphics/examples/twocubes.z3d";

    var stream = Stream{};

    if (!api.transformFile(src_file, &stream.mesh_stream, api.static_geometry)) {
        return 1;
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

    fn writeStaticHeader(mesh_stream: ?*api.MeshStream, vertices: usize, indices: usize, ranges: usize) callconv(.C) void {
        const stream = @fieldParentPtr(Stream, "mesh_stream", mesh_stream.?);
        _ = stream;
        std.log.info("vertices: {},\tindices: {},\ttextures: {}", .{ vertices, indices, ranges });
    }

    fn writeVertex(mesh_stream: ?*api.MeshStream, x: f32, y: f32, z: f32, nx: f32, ny: f32, nz: f32, u: f32, v: f32) callconv(.C) void {
        const stream = @fieldParentPtr(Stream, "mesh_stream", mesh_stream.?);
        _ = stream;
        std.log.info("({d:.3} {d:.3} {d:.3}) ({d:.3} {d:.3} {d:.3}) ({d:.4} {d:.4})", .{ x, y, z, nx, ny, nz, u, v });
    }
    fn writeFace(mesh_stream: ?*api.MeshStream, index0: u16, index1: u16, index2: u16) callconv(.C) void {
        const stream = @fieldParentPtr(Stream, "mesh_stream", mesh_stream.?);
        _ = stream;
        std.log.info("{{{} {} {}}}", .{ index0, index1, index2 });
    }
    fn writeMeshRange(mesh_stream: ?*api.MeshStream, offset: usize, count: usize, texture: ?[*:0]const u8) callconv(.C) void {
        const stream = @fieldParentPtr(Stream, "mesh_stream", mesh_stream.?);
        _ = stream;
        std.log.info("[{} {} \"{s}\"]", .{ offset, count, std.mem.sliceTo(texture.?, 0) });
    }
};
