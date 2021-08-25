const std = @import("std");
const logger = std.log.scoped(.sdl);
const zerog = @import("../zero-graphics.zig");
const c = @import("sdl2");
const Application = @import("application");
const app_meta = @import("application-meta");

comptime {
    // enforce inclusion of "extern  c" implementations
    const common = @import("common.zig");

    // verify the application api
    common.verifyApplication(Application);
}

var window: *c.SDL_Window = undefined;

const debug_window_mode = if (@hasDecl(Application, "zerog_enable_window_mode"))
    Application.zerog_enable_window_mode
else
    false;

pub const milliTimestamp = std.time.milliTimestamp;

const DPI_AWARENESS_CONTEXT_UNAWARE = (DPI_AWARENESS_CONTEXT - 1);
const DPI_AWARENESS_CONTEXT_SYSTEM_AWARE = (DPI_AWARENESS_CONTEXT - 2);
const DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE = (DPI_AWARENESS_CONTEXT - 3);
const DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2 = (DPI_AWARENESS_CONTEXT - 4);
const DPI_AWARENESS_CONTEXT_UNAWARE_GDISCALED = (DPI_AWARENESS_CONTEXT - 5);

const PROCESS_DPI_AWARENESS = enum(c_int) {
    PROCESS_DPI_UNAWARE,
    PROCESS_SYSTEM_DPI_AWARE,
    PROCESS_PER_MONITOR_DPI_AWARE,
};

extern "user32" fn SetProcessDPIAware() callconv(std.os.windows.WINAPI) std.os.windows.BOOL;
// extern "shcore" fn SetProcessDpiAwareness(value: PROCESS_DPI_AWARENESS) callconv(std.os.windows.WINAPI) std.os.windows.HRESULT;

// Desktop entry point
pub fn main() !void {
    // Must happen before *any* SDL calls!
    if (std.builtin.os.tag == .windows) {
        if (SetProcessDPIAware() == std.os.windows.FALSE) {
            logger.warn("Could not set application DPI aware!", .{});
        }
        // const hresult = SetProcessDpiAwareness(.PROCESS_SYSTEM_DPI_AWARE);
        // if (hresult != std.os.windows.S_OK) {
        //     logger.warn("Failed to set process DPI awareness: 0x{X}", .{hresult});
        // }
    }

    _ = c.SDL_Init(c.SDL_INIT_EVERYTHING);
    defer _ = c.SDL_Quit();

    _ = c.SDL_GL_SetAttribute(.SDL_GL_CONTEXT_MAJOR_VERSION, 2);
    _ = c.SDL_GL_SetAttribute(.SDL_GL_CONTEXT_MINOR_VERSION, 0);

    _ = c.SDL_GL_SetAttribute(.SDL_GL_DOUBLEBUFFER, 1);
    //    _ = c.SDL_GL_SetAttribute(.SDL_GL_DEPTH_SIZE, 24);
    if (std.builtin.os.tag == .windows) {
        // We just fake OpenGL ES 2.0 by just loading OpenGL fully /o\
        // _ = c.SDL_GL_SetAttribute(.SDL_GL_CONTEXT_PROFILE_MASK, c.SDL_GL_CONTEXT_PROFILE_ES);
    } else {
        _ = c.SDL_GL_SetAttribute(.SDL_GL_CONTEXT_PROFILE_MASK, c.SDL_GL_CONTEXT_PROFILE_ES);
    }

    if (std.builtin.mode == .Debug) {
        _ = c.SDL_GL_SetAttribute(.SDL_GL_CONTEXT_FLAGS, c.SDL_GL_CONTEXT_DEBUG_FLAG);
    }

    var force_fullscreen: ?bool = null;
    if (!debug_window_mode) {
        force_fullscreen = false;
    }

    if (std.process.getEnvVarOwned(std.heap.c_allocator, "ZEROG_FULLSCREEN")) |env| {
        defer std.heap.c_allocator.free(env);

        if (std.mem.startsWith(u8, env, "y")) {
            force_fullscreen = true;
        } else if (std.mem.startsWith(u8, env, "n")) {
            force_fullscreen = false;
        } else {
            logger.err("Could not parse ZEROG_FULLSCREEN environment variable: Unknown value", .{});
        }
    } else |_| {
        // silently ignore the error here
    }

    const use_fullscreen = force_fullscreen orelse !@hasDecl(app_meta, "initial_resolution");

    var window_flags: u32 = c.SDL_WINDOW_OPENGL | c.SDL_WINDOW_SHOWN | c.SDL_WINDOW_ALLOW_HIGHDPI;
    if (use_fullscreen) {
        window_flags |= c.SDL_WINDOW_FULLSCREEN_DESKTOP;
    }

    var display_mode: c.SDL_DisplayMode = undefined;

    // 0 = primary display
    if (c.SDL_GetDesktopDisplayMode(0, &display_mode) < 0)
        sdlPanic();

    var resolution: c.SDL_Point = undefined;
    if (use_fullscreen) {
        resolution = .{
            .x = display_mode.w,
            .y = display_mode.h,
        };
    } else {
        if (@hasDecl(app_meta, "initial_resolution")) {
            resolution = .{
                .x = app_meta.initial_resolution.width,
                .y = app_meta.initial_resolution.height,
            };
        } else {
            resolution = .{
                .x = 1280,
                .y = 720,
            };
        }
    }

    var input_queue = zerog.Input.init(std.heap.c_allocator);
    defer input_queue.deinit();

    var app: Application = undefined;
    try app.init(std.heap.c_allocator, &input_queue);
    defer app.deinit();

    window = c.SDL_CreateWindow(
        app_meta.display_name,
        c.SDL_WINDOWPOS_CENTERED,
        c.SDL_WINDOWPOS_CENTERED,
        resolution.x,
        resolution.y,
        window_flags,
    ) orelse sdlPanic();
    defer c.SDL_DestroyWindow(window);

    logger.info("SDL Video Driver:     {s}", .{std.mem.span(c.SDL_GetCurrentVideoDriver())});

    const gl_context = c.SDL_GL_CreateContext(window) orelse sdlPanic();
    defer c.SDL_GL_DeleteContext(gl_context);

    const dpi_scale: f32 = blk: {
        var drawbable_width: c_int = undefined;
        var drawbable_height: c_int = undefined;
        c.SDL_GL_GetDrawableSize(window, &drawbable_width, &drawbable_height);
        logger.info("Render resolution:  {}×{}", .{ drawbable_width, drawbable_height });

        var virtual_width: c_int = undefined;
        var virtual_height: c_int = undefined;
        c.SDL_GetWindowSize(window, &virtual_width, &virtual_height);
        logger.info("Virtual resolution: {}×{}", .{ virtual_width, virtual_height });

        const scale_x = @intToFloat(f32, drawbable_width) / @intToFloat(f32, virtual_width);
        const scale_y = @intToFloat(f32, drawbable_height) / @intToFloat(f32, virtual_height);
        std.debug.assert(std.math.approxEqAbs(f32, scale_x, scale_y, 1e-3)); // assert uniform
        break :blk scale_x;
    };

    try zerog.gles.load({}, loadOpenGlFunction);

    try app.setupGraphics();
    defer app.teardownGraphics();

    // resize application
    {
        var width: c_int = undefined;
        var height: c_int = undefined;

        c.SDL_GL_GetDrawableSize(window, &width, &height);
        try app.resize(@intCast(u15, width), @intCast(u15, height));
    }

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
                        // logger.info("unhandled window event: {}", .{@intToEnum(c.SDL_WindowEventID, event.window.event)});
                    }
                },

                else => {}, //logger.info("unhandled event: {}", .{@intToEnum(c.SDL_EventType, event.type)}),
            }
        }

        const still_running = try app.update();
        if (still_running == false)
            break;
        try app.render();
        c.SDL_GL_SwapWindow(window);
    }
}

pub fn loadOpenGlFunction(_: void, function: [:0]const u8) ?*const c_void {
    // logger.debug("getting entry point for '{s}'", .{function});
    return c.SDL_GL_GetProcAddress(function.ptr);
}

fn sdlPanic() noreturn {
    @panic(std.mem.span(c.SDL_GetError()));
}

pub fn getDisplayDPI() f32 {
    // Env var always overrides the
    if (std.process.getEnvVarOwned(std.heap.c_allocator, "DUNSTBLICK_DPI")) |env| {
        defer std.heap.c_allocator.free(env);
        if (std.fmt.parseFloat(f32, env)) |value| {
            return value;
        } else |err| {
            logger.err("Could not parse DUNSTBLICK_DPI environment variable: {s}", .{@errorName(err)});
        }
    } else |_| {
        // silently ignore the error here
    }

    var fallback: f32 = 96.0; // Default DPI

    var index = c.SDL_GetWindowDisplayIndex(window);
    if (index < 0) {
        return fallback;
    }

    var diagonal_dpi: f32 = undefined;
    if (c.SDL_GetDisplayDPI(index, &diagonal_dpi, null, null) < 0) {
        return fallback;
    }
    return diagonal_dpi;
}
