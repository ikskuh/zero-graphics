const std = @import("std");
const log = std.log.scoped(.sdl);
const root = @import("root");
const zerog = @import("../zero-graphics.zig");
const c = @cImport({
    @cInclude("SDL.h");
});

// Desktop entry point
pub fn main() !void {
    _ = c.SDL_Init(c.SDL_INIT_EVERYTHING);
    defer _ = c.SDL_Quit();

    _ = c.SDL_GL_SetAttribute(.SDL_GL_CONTEXT_MAJOR_VERSION, 2);
    _ = c.SDL_GL_SetAttribute(.SDL_GL_CONTEXT_MINOR_VERSION, 0);

    _ = c.SDL_GL_SetAttribute(.SDL_GL_DOUBLEBUFFER, 1);
    //    _ = c.SDL_GL_SetAttribute(.SDL_GL_DEPTH_SIZE, 24);
    _ = c.SDL_GL_SetAttribute(.SDL_GL_CONTEXT_PROFILE_MASK, c.SDL_GL_CONTEXT_PROFILE_ES);

    if (std.builtin.mode == .Debug) {
        _ = c.SDL_GL_SetAttribute(.SDL_GL_CONTEXT_FLAGS, c.SDL_GL_CONTEXT_DEBUG_FLAG);
    }

    const window = c.SDL_CreateWindow(
        "OpenGL ES 2.0 - Zig Demo",
        c.SDL_WINDOWPOS_CENTERED,
        c.SDL_WINDOWPOS_CENTERED,
        640,
        480,
        c.SDL_WINDOW_OPENGL | c.SDL_WINDOW_SHOWN | c.SDL_WINDOW_ALLOW_HIGHDPI | c.SDL_WINDOW_MAXIMIZED | c.SDL_WINDOW_FULLSCREEN_DESKTOP,
    ) orelse sdlPanic();
    defer c.SDL_DestroyWindow(window);

    log.info("SDL Video Driver:     {s}", .{std.mem.span(c.SDL_GetCurrentVideoDriver())});

    const gl_context = c.SDL_GL_CreateContext(window) orelse sdlPanic();
    defer c.SDL_GL_DeleteContext(gl_context);

    const dpi_scale: f32 = blk: {
        var drawbable_width: c_int = undefined;
        var drawbable_height: c_int = undefined;
        c.SDL_GL_GetDrawableSize(window, &drawbable_width, &drawbable_height);
        log.info("Render resolution:  {}×{}", .{ drawbable_width, drawbable_height });

        var virtual_width: c_int = undefined;
        var virtual_height: c_int = undefined;
        c.SDL_GetWindowSize(window, &virtual_width, &virtual_height);
        log.info("Virtual resolution: {}×{}", .{ virtual_width, virtual_height });

        const scale_x = @intToFloat(f32, drawbable_width) / @intToFloat(f32, virtual_width);
        const scale_y = @intToFloat(f32, drawbable_height) / @intToFloat(f32, virtual_height);
        std.debug.assert(std.math.approxEqAbs(f32, scale_x, scale_y, 1e-3)); // assert uniform
        break :blk scale_x;
    };

    var input_queue = zerog.Input.init(std.heap.c_allocator);
    defer input_queue.deinit();

    var app: root.Application = undefined;
    try app.init(std.heap.c_allocator, &input_queue);
    defer app.deinit();

    while (true) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                c.SDL_QUIT => {
                    try input_queue.pushEvent(.quit);
                },
                c.SDL_MOUSEMOTION => {
                    try input_queue.pushEvent(.{ .pointer_motion = .{
                        .x = @floatToInt(i16, dpi_scale * @intToFloat(f32, event.motion.x)),
                        .y = @floatToInt(i16, dpi_scale * @intToFloat(f32, event.motion.y)),
                    } });
                },
                c.SDL_MOUSEBUTTONDOWN => {
                    switch (event.button.button) {
                        c.SDL_BUTTON_LEFT => try input_queue.pushEvent(.{ .pointer_press = .primary }),
                        c.SDL_BUTTON_RIGHT => try input_queue.pushEvent(.{ .pointer_press = .secondary }),
                        else => {},
                    }
                },
                c.SDL_MOUSEBUTTONUP => {
                    switch (event.button.button) {
                        c.SDL_BUTTON_LEFT => try input_queue.pushEvent(.{ .pointer_release = .primary }),
                        c.SDL_BUTTON_RIGHT => try input_queue.pushEvent(.{ .pointer_release = .secondary }),
                        else => {},
                    }
                },
                c.SDL_TEXTINPUT => {
                    const keys = c.SDL_GetKeyboardState(null);
                    try input_queue.pushEvent(.{ .text_input = .{
                        .text = std.mem.sliceTo(&event.text.text, 0),
                        .modifiers = .{
                            .shift = (keys[c.SDL_SCANCODE_LSHIFT] != 0) or (keys[c.SDL_SCANCODE_RSHIFT] != 0),
                            .alt = (keys[c.SDL_SCANCODE_LALT] != 0) or (keys[c.SDL_SCANCODE_RALT] != 0),
                            .ctrl = (keys[c.SDL_SCANCODE_LCTRL] != 0) or (keys[c.SDL_SCANCODE_RCTRL] != 0),
                            .super = (keys[c.SDL_SCANCODE_LGUI] != 0) or (keys[c.SDL_SCANCODE_RGUI] != 0),
                        },
                    } });
                },
                c.SDL_WINDOWEVENT => {
                    if (event.window.event == c.SDL_WINDOWEVENT_SIZE_CHANGED) {
                        var width: c_int = undefined;
                        var height: c_int = undefined;

                        c.SDL_GL_GetDrawableSize(window, &width, &height);

                        try app.resize(@intCast(u15, width), @intCast(u15, height));
                    } else {
                        log.info("unhandled window event: {}", .{@intToEnum(c.SDL_WindowEventID, event.window.event)});
                    }
                },
                
                else => log.info("unhandled event: {}", .{@intToEnum(c.SDL_EventType, @intCast(c_int, event.type))}),
            }
        }

        const still_running = try app.update();
        if (still_running == false)
            break;
        c.SDL_GL_SwapWindow(window);
    }
}

fn sdlPanic() noreturn {
    @panic(std.mem.span(c.SDL_GetError()));
}

pub fn loadOpenGlFunction(ctx: void, function: [:0]const u8) ?*const c_void {
    // log.debug("getting entry point for '{s}'", .{function});
    return c.SDL_GL_GetProcAddress(function.ptr);
}
