const std = @import("std");

// fn init(app: *Application, allocator: std.mem.Allocator) !void
// fn setupGraphics(app: *Application) !void
// fn resize(app: *Application, width: u15, height: u15) !void
// fn update(app: *Application) !bool
// fn render(app: *Application) !void
// fn teardownGraphics(app: *Application) void
// fn deinit(app: *Application) void

pub fn verifyApplication(comptime T: type) void {
    if (!@hasDecl(T, "init")) @compileError("Application file must export 'fn init(app: *Application, allocator: std.mem.Allocator) !void'");
    if (!@hasDecl(T, "setupGraphics")) @compileError("Application file must export 'fn setupGraphics(app: *Application) !void'");
    if (!@hasDecl(T, "resize")) @compileError("Application file must export 'fn resize(app: *Application, width: u15, height: u15) !void'");
    if (!@hasDecl(T, "update")) @compileError("Application file must export 'fn update(app: *Application) !bool'");
    if (!@hasDecl(T, "render")) @compileError("Application file must export 'fn render(app: *Application) !void'");
    if (!@hasDecl(T, "teardownGraphics")) @compileError("Application file must export 'fn teardownGraphics(app: *Application) void'");
    if (!@hasDecl(T, "deinit")) @compileError("Application file must export 'fn deinit(app: *Application) void'");

    // TODO: Verify signatures
}

export fn zerog_renderer2d_alloc(user_data: ?*c_void, size: usize) ?*c_void {
    std.log.info("stbttf: alloc {} bytes with {}", .{ size, user_data });
    const allocator = @ptrCast(*std.mem.Allocator, @alignCast(@alignOf(*std.mem.Allocator), user_data orelse @panic("unexpected NULl!")));

    const buffer = allocator.allocAdvanced(u8, 16, size + 16, .exact) catch return null;
    std.mem.writeIntNative(usize, buffer[0..@sizeOf(usize)], buffer.len);
    return buffer.ptr + 16;
}

export fn zerog_renderer2d_free(user_data: ?*c_void, ptr: ?*c_void) void {
    std.log.info("stbttf: free {} with {}", .{ ptr, user_data });
    const allocator = @ptrCast(*std.mem.Allocator, @alignCast(@alignOf(*std.mem.Allocator), user_data orelse @panic("unexpected NULl!")));

    const actual_buffer = @ptrCast([*]u8, ptr orelse return) - 16;
    const len = std.mem.readIntNative(usize, actual_buffer[0..@sizeOf(usize)]);

    allocator.free(actual_buffer[0..len]);
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
