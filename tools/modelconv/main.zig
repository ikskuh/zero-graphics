const std = @import("std");

const FileType = enum(c_int) { dynamic = 0, static = 1 };

extern fn transformFile(
    src_file_name: [*:0]const u8,
    dst_file_name: [*:0]const u8,
    file_type: FileType,
) bool;

pub fn main() !u8 {
    const src_file = "/home/felix/projects/experiments/zero3d/vendor/zero-graphics/examples/data/twocubes.obj";
    const dst_file = "/home/felix/projects/experiments/zero3d/vendor/zero-graphics/examples/twocubes.z3d";

    if (!transformFile(src_file, dst_file, .static)) {
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
