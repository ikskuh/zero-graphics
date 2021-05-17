const std = @import("std");
const wasm = std.log.scoped(.sdl);
const root = @import("root");
const gles = @import("../gl_es_2v0.zig");

pub fn loadOpenGlFunction(ctx: void, function: [:0]const u8) ?*c_void {
    @panic("not implemented yet!");
}
