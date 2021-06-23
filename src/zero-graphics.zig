const std = @import("std");

pub const Backend = enum {
    desktop_sdl2,
    wasm,
    android,
};

// TODO:
// Specify application type for the backend, so we can remove the `@import("root").Application` reference
pub fn Api(comptime backend: Backend) type {
    const BackendImpl = switch (backend) {
        .desktop_sdl2 => @import("backend/sdl.zig"),
        .wasm => @import("backend/wasm.zig"),
        .android => @import("backend/android.zig"),
    };

    const T = struct {
        pub usingnamespace BackendImpl;

        pub usingnamespace @import("common.zig");
    };

    const required_exports = [_][]const u8{
        "entry_point",
        "loadOpenGlFunction",
        "milliTimestamp",
    };

    inline for (required_exports) |export_name| {
        if (!@hasDecl(T, export_name))
            @compileError("Backend is missing symbol " ++ export_name ++ "!");
    }
    return T;
}

export fn zerog_panic(msg: [*:0]const u8) noreturn {
    @panic(std.mem.span(msg));
}

export fn zerog_ifloor(v: f64) c_int {
    return @floatToInt(c_int, std.math.floor(v));
}

export fn zerog_iceil(v: f64) c_int {
    return @floatToInt(c_int, std.math.ceil(v));
}

export fn zerog_sqrt(v: f64) f64 {
    return std.math.sqrt(v);
}
export fn zerog_pow(a: f64, b: f64) f64 {
    return std.math.pow(f64, a, b);
}
export fn zerog_fmod(a: f64, b: f64) f64 {
    return @mod(a, b);
}
export fn zerog_cos(v: f64) f64 {
    return std.math.cos(v);
}
export fn zerog_acos(v: f64) f64 {
    return std.math.acos(v);
}
export fn zerog_fabs(v: f64) f64 {
    return std.math.fabs(v);
}
export fn zerog_strlen(str: ?[*:0]const u8) usize {
    return std.mem.len(str orelse return 0);
}
export fn zerog_memcpy(dst: ?[*]u8, src: ?[*]const u8, num: usize) ?[*]u8 {
    if (dst == null or src == null)
        @panic("Invalid usage of memcpy!");
    std.mem.copy(u8, dst.?[0..num], src.?[0..num]);
    return dst;
}
export fn zerog_memset(ptr: ?[*]u8, value: c_int, num: usize) ?[*]u8 {
    if (ptr == null)
        @panic("Invalid usage of memset!");
    std.mem.set(u8, ptr.?[0..num], @intCast(u8, value));
    return ptr;
}
