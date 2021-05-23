const std = @import("std");

// opengl docs can be found here:
// https://www.khronos.org/registry/OpenGL-Refpages/es2.0/
pub const gles = @import("gl_es_2v0.zig");

pub const Backend = enum {
    desktop_sdl2,
    wasm,
    android,
};

pub fn EntryPoint(comptime backend: Backend) type {
    return switch (backend) {
        .desktop_sdl2 => @import("backend/sdl.zig"),
        .wasm => @import("backend/wasm.zig"),
        .android => @import("backend/android.zig"),
    };
}

pub const Renderer2D = @import("rendering/Renderer2D.zig");

export fn zerog_panic(msg: [*:0]const u8) noreturn {
    @panic(std.mem.span(msg));
}
