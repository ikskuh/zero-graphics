const std = @import("std");

pub const FileType = enum(u8) { static = 0, dynamic = 1, _ };
pub const magic_number = [4]u8{ 0xae, 0x32, 0x51, 0x1d };

pub const CommonHeader = extern struct {
    magic: [4]u8 = magic_number,

    version: u16 = std.mem.nativeToLittle(u16, 1),
    type: FileType,
    _pad0: u8 = undefined,
};

pub const static_model = struct {
    comptime {
        if (@sizeOf(Header) != 24) @compileError("Header must have 24 byte!");
        if (@sizeOf(Vertex) != 32) @compileError("Vertex must have 32 byte!");
        if (@sizeOf(Index) != 2) @compileError("Index must have 2 byte!");
        if (@sizeOf(Mesh) != 128) @compileError("Mesh must have 128 byte!");
    }

    // size: 24
    pub const Header = extern struct {
        common: CommonHeader,
        vertex_count: u32,
        index_count: u32,
        mesh_count: u32,
        _pad1: u32 = undefined,
    };

    // size: 32
    pub const Vertex = extern struct {
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
    pub const Index = u16;

    // size: 128
    pub const Mesh = extern struct {
        offset: u32,
        length: u32,
        texture_file: [120]u8, // NUL padded
    };
};
