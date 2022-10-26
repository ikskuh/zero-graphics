const std = @import("std");
const builtin = @import("builtin");
const logger = std.log.scoped(.sdl);
const zerog = @import("../zero-graphics.zig");
const c = @import("sdl2");
pub const Application = @import("application");
const app_meta = @import("application-meta");
pub const CoreApplication = @import("../CoreApplication.zig");
pub const build_options = @import("build_options");

pub const backend: zerog.Backend = .desktop;

comptime {
    // enforce inclusion of "extern  c" implementations
    _ = @import("common.zig");
}

var window: *c.SDL_Window = undefined;

const debug_window_mode = if (@hasDecl(Application, "zerog_enable_window_mode"))
    Application.zerog_enable_window_mode
else
    false;

var startup_time: i64 = 0;
pub fn milliTimestamp() i64 {
    return std.time.milliTimestamp() - startup_time;
}

// const DPI_AWARENESS_CONTEXT_UNAWARE = (DPI_AWARENESS_CONTEXT - 1);
// const DPI_AWARENESS_CONTEXT_SYSTEM_AWARE = (DPI_AWARENESS_CONTEXT - 2);
// const DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE = (DPI_AWARENESS_CONTEXT - 3);
// const DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2 = (DPI_AWARENESS_CONTEXT - 4);
// const DPI_AWARENESS_CONTEXT_UNAWARE_GDISCALED = (DPI_AWARENESS_CONTEXT - 5);

const PROCESS_DPI_AWARENESS = enum(c_int) {
    PROCESS_DPI_UNAWARE,
    PROCESS_SYSTEM_DPI_AWARE,
    PROCESS_PER_MONITOR_DPI_AWARE,
};

extern "user32" fn SetProcessDPIAware() callconv(std.os.windows.WINAPI) std.os.windows.BOOL;
// extern "shcore" fn SetProcessDpiAwareness(value: PROCESS_DPI_AWARENESS) callconv(std.os.windows.WINAPI) std.os.windows.HRESULT;

fn logAppError(context: []const u8, trace: ?*std.builtin.StackTrace, err: anytype) @TypeOf(err) {
    if (trace) |st| {
        std.debug.dumpStackTrace(st.*);
    }
    std.log.scoped(.application).err("Application failed in {s}: {s}", .{ context, @errorName(err) });
    return err;
}

// Desktop entry point
pub fn main() !void {
    // Must happen before *any* SDL calls!
    if (builtin.os.tag == .windows) {
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

    _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MAJOR_VERSION, 2);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MINOR_VERSION, 0);

    _ = c.SDL_GL_SetAttribute(c.SDL_GL_DOUBLEBUFFER, 1);

    _ = c.SDL_GL_SetAttribute(c.SDL_GL_MULTISAMPLEBUFFERS, 1);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_MULTISAMPLESAMPLES, 4);

    //    _ = c.SDL_GL_SetAttribute(.SDL_GL_DEPTH_SIZE, 24);
    if (builtin.os.tag == .windows) {
        // We just fake OpenGL ES 2.0 by just loading OpenGL fully /o\
        // _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_PROFILE_MASK, c.SDL_GL_CONTEXT_PROFILE_ES);
    } else {
        _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_PROFILE_MASK, c.SDL_GL_CONTEXT_PROFILE_ES);
    }

    if (builtin.mode == .Debug) {
        _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_FLAGS, c.SDL_GL_CONTEXT_DEBUG_FLAG);
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

    var allow_resize: bool = if (@hasDecl(app_meta, "allow_resize")) app_meta.allow_resize else false; // no resize by default
    if (std.process.getEnvVarOwned(std.heap.c_allocator, "ZEROG_RESIZEABLE")) |env| {
        defer std.heap.c_allocator.free(env);

        if (std.mem.startsWith(u8, env, "y")) {
            allow_resize = true;
        } else if (std.mem.startsWith(u8, env, "n")) {
            allow_resize = false;
        } else {
            logger.err("Could not parse ZEROG_RESIZEABLE environment variable: Unknown value", .{});
        }
    } else |_| {
        // silently ignore the error here
    }

    const use_fullscreen = force_fullscreen orelse !@hasDecl(app_meta, "initial_resolution");

    var window_flags: u32 = c.SDL_WINDOW_OPENGL | c.SDL_WINDOW_SHOWN | c.SDL_WINDOW_ALLOW_HIGHDPI;
    if (use_fullscreen) {
        window_flags |= c.SDL_WINDOW_FULLSCREEN_DESKTOP;
    }
    if (allow_resize) {
        window_flags |= c.SDL_WINDOW_RESIZABLE;
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

    if (build_options.enable_code_editor) {
        try zerog.CodeEditor.init();
    }
    defer if (build_options.enable_code_editor) {
        zerog.CodeEditor.deinit();
    };

    startup_time = std.time.milliTimestamp();

    var app: CoreApplication = undefined;
    app.init(std.heap.c_allocator, &input_queue) catch |e| return logAppError("init", @errorReturnTrace(), e);
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

    var gl_context = c.SDL_GL_CreateContext(window) orelse sdlPanic();
    defer c.SDL_GL_DeleteContext(gl_context);

    try zerog.gles.load({}, loadOpenGlFunction);

    app.setupGraphics() catch |e| return logAppError("setupGraphics", @errorReturnTrace(), e);
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
                c.SDL_KEYDOWN => { // if (event.key.repeat == 0)

                    // Shift-F12 will recreate the opengl context
                    if (builtin.mode == .Debug and ((event.key.keysym.mod & c.KMOD_SHIFT) != 0) and event.key.keysym.sym == c.SDLK_F12) {
                        c.SDL_GL_DeleteContext(gl_context);
                        gl_context = c.SDL_GL_CreateContext(window) orelse sdlPanic();

                        try zerog.gles.load({}, loadOpenGlFunction);

                        const begin = std.time.milliTimestamp();
                        app.teardownGraphics();
                        app.setupGraphics() catch |e| return logAppError("setupGraphics", @errorReturnTrace(), e);
                        const end = std.time.milliTimestamp();
                        logger.info("GPU context reload took {} ms", .{end - begin});
                    }

                    if (translateSdlScancode(event.key.keysym.scancode)) |scancode| {
                        try input_queue.pushEvent(.{ .key_down = scancode });
                    }
                },
                c.SDL_KEYUP => {
                    if (translateSdlScancode(event.key.keysym.scancode)) |scancode| {
                        try input_queue.pushEvent(.{ .key_up = scancode });
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
                        app.resize(@intCast(u15, width), @intCast(u15, height)) catch |e| return logAppError("resize", @errorReturnTrace(), e);
                    } else {
                        // logger.info("unhandled window event: {}", .{@intToEnum(c.SDL_WindowEventID, event.window.event)});
                    }
                },

                else => {}, //logger.info("unhandled event: {}", .{@intToEnum(c.SDL_EventType, event.type)}),
            }
        }

        const still_running = app.update() catch |e| return logAppError("update", @errorReturnTrace(), e);
        if (still_running == false)
            break;
        app.render() catch |e| return logAppError("render", @errorReturnTrace(), e);
        c.SDL_GL_SwapWindow(window);
    }
}

fn translateSdlScancode(scancode: c.SDL_Scancode) ?zerog.Input.Scancode {
    const SC = zerog.Input.Scancode;
    return switch (scancode) {
        c.SDL_SCANCODE_A => SC.a,
        c.SDL_SCANCODE_B => SC.b,
        c.SDL_SCANCODE_C => SC.c,
        c.SDL_SCANCODE_D => SC.d,
        c.SDL_SCANCODE_E => SC.e,
        c.SDL_SCANCODE_F => SC.f,
        c.SDL_SCANCODE_G => SC.g,
        c.SDL_SCANCODE_H => SC.h,
        c.SDL_SCANCODE_I => SC.i,
        c.SDL_SCANCODE_J => SC.j,
        c.SDL_SCANCODE_K => SC.k,
        c.SDL_SCANCODE_L => SC.l,
        c.SDL_SCANCODE_M => SC.m,
        c.SDL_SCANCODE_N => SC.n,
        c.SDL_SCANCODE_O => SC.o,
        c.SDL_SCANCODE_P => SC.p,
        c.SDL_SCANCODE_Q => SC.q,
        c.SDL_SCANCODE_R => SC.r,
        c.SDL_SCANCODE_S => SC.s,
        c.SDL_SCANCODE_T => SC.t,
        c.SDL_SCANCODE_U => SC.u,
        c.SDL_SCANCODE_V => SC.v,
        c.SDL_SCANCODE_W => SC.w,
        c.SDL_SCANCODE_X => SC.x,
        c.SDL_SCANCODE_Y => SC.y,
        c.SDL_SCANCODE_Z => SC.z,
        c.SDL_SCANCODE_1 => SC.@"1",
        c.SDL_SCANCODE_2 => SC.@"2",
        c.SDL_SCANCODE_3 => SC.@"3",
        c.SDL_SCANCODE_4 => SC.@"4",
        c.SDL_SCANCODE_5 => SC.@"5",
        c.SDL_SCANCODE_6 => SC.@"6",
        c.SDL_SCANCODE_7 => SC.@"7",
        c.SDL_SCANCODE_8 => SC.@"8",
        c.SDL_SCANCODE_9 => SC.@"9",
        c.SDL_SCANCODE_0 => SC.@"0",
        c.SDL_SCANCODE_RETURN => SC.@"return",
        c.SDL_SCANCODE_ESCAPE => SC.escape,
        c.SDL_SCANCODE_BACKSPACE => SC.backspace,
        c.SDL_SCANCODE_TAB => SC.tab,
        c.SDL_SCANCODE_SPACE => SC.space,
        c.SDL_SCANCODE_MINUS => SC.minus,
        c.SDL_SCANCODE_EQUALS => SC.equals,
        c.SDL_SCANCODE_LEFTBRACKET => SC.left_bracket,
        c.SDL_SCANCODE_RIGHTBRACKET => SC.right_bracket,
        c.SDL_SCANCODE_BACKSLASH => SC.backslash,
        c.SDL_SCANCODE_NONUSHASH => SC.nonushash,
        c.SDL_SCANCODE_SEMICOLON => SC.semicolon,
        c.SDL_SCANCODE_APOSTROPHE => SC.apostrophe,
        c.SDL_SCANCODE_GRAVE => SC.grave,
        c.SDL_SCANCODE_COMMA => SC.comma,
        c.SDL_SCANCODE_PERIOD => SC.period,
        c.SDL_SCANCODE_SLASH => SC.slash,
        c.SDL_SCANCODE_CAPSLOCK => SC.caps_lock,
        c.SDL_SCANCODE_PRINTSCREEN => SC.print_screen,
        c.SDL_SCANCODE_SCROLLLOCK => SC.scroll_lock,
        c.SDL_SCANCODE_PAUSE => SC.pause,
        c.SDL_SCANCODE_INSERT => SC.insert,
        c.SDL_SCANCODE_HOME => SC.home,
        c.SDL_SCANCODE_PAGEUP => SC.page_up,
        c.SDL_SCANCODE_DELETE => SC.delete,
        c.SDL_SCANCODE_END => SC.end,
        c.SDL_SCANCODE_PAGEDOWN => SC.page_down,
        c.SDL_SCANCODE_RIGHT => SC.right,
        c.SDL_SCANCODE_LEFT => SC.left,
        c.SDL_SCANCODE_DOWN => SC.down,
        c.SDL_SCANCODE_UP => SC.up,
        c.SDL_SCANCODE_NUMLOCKCLEAR => SC.num_lock_clear,
        c.SDL_SCANCODE_KP_DIVIDE => SC.keypad_divide,
        c.SDL_SCANCODE_KP_MULTIPLY => SC.keypad_multiply,
        c.SDL_SCANCODE_KP_MINUS => SC.keypad_minus,
        c.SDL_SCANCODE_KP_PLUS => SC.keypad_plus,
        c.SDL_SCANCODE_KP_ENTER => SC.keypad_enter,
        c.SDL_SCANCODE_KP_1 => SC.keypad_1,
        c.SDL_SCANCODE_KP_2 => SC.keypad_2,
        c.SDL_SCANCODE_KP_3 => SC.keypad_3,
        c.SDL_SCANCODE_KP_4 => SC.keypad_4,
        c.SDL_SCANCODE_KP_5 => SC.keypad_5,
        c.SDL_SCANCODE_KP_6 => SC.keypad_6,
        c.SDL_SCANCODE_KP_7 => SC.keypad_7,
        c.SDL_SCANCODE_KP_8 => SC.keypad_8,
        c.SDL_SCANCODE_KP_9 => SC.keypad_9,
        c.SDL_SCANCODE_KP_0 => SC.keypad_0,
        c.SDL_SCANCODE_KP_00 => SC.keypad_00,
        c.SDL_SCANCODE_KP_000 => SC.keypad_000,
        c.SDL_SCANCODE_KP_PERIOD => SC.keypad_period,
        c.SDL_SCANCODE_KP_COMMA => SC.keypad_comma,
        c.SDL_SCANCODE_KP_EQUALSAS400 => SC.keypad_equalsas400,
        c.SDL_SCANCODE_KP_LEFTPAREN => SC.keypad_leftparen,
        c.SDL_SCANCODE_KP_RIGHTPAREN => SC.keypad_rightparen,
        c.SDL_SCANCODE_KP_LEFTBRACE => SC.keypad_leftbrace,
        c.SDL_SCANCODE_KP_RIGHTBRACE => SC.keypad_rightbrace,
        c.SDL_SCANCODE_KP_TAB => SC.keypad_tab,
        c.SDL_SCANCODE_KP_BACKSPACE => SC.keypad_backspace,
        c.SDL_SCANCODE_KP_A => SC.keypad_a,
        c.SDL_SCANCODE_KP_B => SC.keypad_b,
        c.SDL_SCANCODE_KP_C => SC.keypad_c,
        c.SDL_SCANCODE_KP_D => SC.keypad_d,
        c.SDL_SCANCODE_KP_E => SC.keypad_e,
        c.SDL_SCANCODE_KP_F => SC.keypad_f,
        c.SDL_SCANCODE_KP_XOR => SC.keypad_xor,
        c.SDL_SCANCODE_KP_POWER => SC.keypad_power,
        c.SDL_SCANCODE_KP_PERCENT => SC.keypad_percent,
        c.SDL_SCANCODE_KP_LESS => SC.keypad_less,
        c.SDL_SCANCODE_KP_GREATER => SC.keypad_greater,
        c.SDL_SCANCODE_KP_AMPERSAND => SC.keypad_ampersand,
        c.SDL_SCANCODE_KP_DBLAMPERSAND => SC.keypad_dblampersand,
        c.SDL_SCANCODE_KP_VERTICALBAR => SC.keypad_verticalbar,
        c.SDL_SCANCODE_KP_DBLVERTICALBAR => SC.keypad_dblverticalbar,
        c.SDL_SCANCODE_KP_COLON => SC.keypad_colon,
        c.SDL_SCANCODE_KP_HASH => SC.keypad_hash,
        c.SDL_SCANCODE_KP_SPACE => SC.keypad_space,
        c.SDL_SCANCODE_KP_AT => SC.keypad_at,
        c.SDL_SCANCODE_KP_EXCLAM => SC.keypad_exclam,
        c.SDL_SCANCODE_KP_MEMSTORE => SC.keypad_memstore,
        c.SDL_SCANCODE_KP_MEMRECALL => SC.keypad_memrecall,
        c.SDL_SCANCODE_KP_MEMCLEAR => SC.keypad_memclear,
        c.SDL_SCANCODE_KP_MEMADD => SC.keypad_memadd,
        c.SDL_SCANCODE_KP_MEMSUBTRACT => SC.keypad_memsubtract,
        c.SDL_SCANCODE_KP_MEMMULTIPLY => SC.keypad_memmultiply,
        c.SDL_SCANCODE_KP_MEMDIVIDE => SC.keypad_memdivide,
        c.SDL_SCANCODE_KP_PLUSMINUS => SC.keypad_plusminus,
        c.SDL_SCANCODE_KP_CLEAR => SC.keypad_clear,
        c.SDL_SCANCODE_KP_CLEARENTRY => SC.keypad_clearentry,
        c.SDL_SCANCODE_KP_BINARY => SC.keypad_binary,
        c.SDL_SCANCODE_KP_OCTAL => SC.keypad_octal,
        c.SDL_SCANCODE_KP_DECIMAL => SC.keypad_decimal,
        c.SDL_SCANCODE_KP_HEXADECIMAL => SC.keypad_hexadecimal,
        c.SDL_SCANCODE_KP_EQUALS => SC.keypad_equals,
        c.SDL_SCANCODE_F1 => SC.f1,
        c.SDL_SCANCODE_F2 => SC.f2,
        c.SDL_SCANCODE_F3 => SC.f3,
        c.SDL_SCANCODE_F4 => SC.f4,
        c.SDL_SCANCODE_F5 => SC.f5,
        c.SDL_SCANCODE_F6 => SC.f6,
        c.SDL_SCANCODE_F7 => SC.f7,
        c.SDL_SCANCODE_F8 => SC.f8,
        c.SDL_SCANCODE_F9 => SC.f9,
        c.SDL_SCANCODE_F10 => SC.f10,
        c.SDL_SCANCODE_F11 => SC.f11,
        c.SDL_SCANCODE_F12 => SC.f12,
        c.SDL_SCANCODE_F13 => SC.f13,
        c.SDL_SCANCODE_F14 => SC.f14,
        c.SDL_SCANCODE_F15 => SC.f15,
        c.SDL_SCANCODE_F16 => SC.f16,
        c.SDL_SCANCODE_F17 => SC.f17,
        c.SDL_SCANCODE_F18 => SC.f18,
        c.SDL_SCANCODE_F19 => SC.f19,
        c.SDL_SCANCODE_F20 => SC.f20,
        c.SDL_SCANCODE_F21 => SC.f21,
        c.SDL_SCANCODE_F22 => SC.f22,
        c.SDL_SCANCODE_F23 => SC.f23,
        c.SDL_SCANCODE_F24 => SC.f24,
        c.SDL_SCANCODE_NONUSBACKSLASH => SC.nonusbackslash,
        c.SDL_SCANCODE_APPLICATION => SC.application,
        c.SDL_SCANCODE_POWER => SC.power,
        c.SDL_SCANCODE_EXECUTE => SC.execute,
        c.SDL_SCANCODE_HELP => SC.help,
        c.SDL_SCANCODE_MENU => SC.menu,
        c.SDL_SCANCODE_SELECT => SC.select,
        c.SDL_SCANCODE_STOP => SC.stop,
        c.SDL_SCANCODE_AGAIN => SC.again,
        c.SDL_SCANCODE_UNDO => SC.undo,
        c.SDL_SCANCODE_CUT => SC.cut,
        c.SDL_SCANCODE_COPY => SC.copy,
        c.SDL_SCANCODE_PASTE => SC.paste,
        c.SDL_SCANCODE_FIND => SC.find,
        c.SDL_SCANCODE_MUTE => SC.mute,
        c.SDL_SCANCODE_VOLUMEUP => SC.volumeup,
        c.SDL_SCANCODE_VOLUMEDOWN => SC.volumedown,
        c.SDL_SCANCODE_ALTERASE => SC.alterase,
        c.SDL_SCANCODE_SYSREQ => SC.sysreq,
        c.SDL_SCANCODE_CANCEL => SC.cancel,
        c.SDL_SCANCODE_CLEAR => SC.clear,
        c.SDL_SCANCODE_PRIOR => SC.prior,
        c.SDL_SCANCODE_RETURN2 => SC.return2,
        c.SDL_SCANCODE_SEPARATOR => SC.separator,
        c.SDL_SCANCODE_OUT => SC.out,
        c.SDL_SCANCODE_OPER => SC.oper,
        c.SDL_SCANCODE_CLEARAGAIN => SC.clearagain,
        c.SDL_SCANCODE_CRSEL => SC.crsel,
        c.SDL_SCANCODE_EXSEL => SC.exsel,
        c.SDL_SCANCODE_THOUSANDSSEPARATOR => SC.thousandsseparator,
        c.SDL_SCANCODE_DECIMALSEPARATOR => SC.decimalseparator,
        c.SDL_SCANCODE_CURRENCYUNIT => SC.currencyunit,
        c.SDL_SCANCODE_CURRENCYSUBUNIT => SC.currencysubunit,
        c.SDL_SCANCODE_LCTRL => SC.ctrl_left,
        c.SDL_SCANCODE_LSHIFT => SC.shift_left,
        c.SDL_SCANCODE_LALT => SC.alt_left,
        c.SDL_SCANCODE_LGUI => SC.gui_left,
        c.SDL_SCANCODE_RCTRL => SC.ctrl_right,
        c.SDL_SCANCODE_RSHIFT => SC.shift_right,
        c.SDL_SCANCODE_RALT => SC.alt_right,
        c.SDL_SCANCODE_RGUI => SC.gui_right,
        c.SDL_SCANCODE_MODE => SC.mode,
        c.SDL_SCANCODE_AUDIONEXT => SC.audio_next,
        c.SDL_SCANCODE_AUDIOPREV => SC.audio_prev,
        c.SDL_SCANCODE_AUDIOSTOP => SC.audio_stop,
        c.SDL_SCANCODE_AUDIOPLAY => SC.audio_play,
        c.SDL_SCANCODE_AUDIOMUTE => SC.audio_mute,
        c.SDL_SCANCODE_AUDIOREWIND => SC.audio_rewind,
        c.SDL_SCANCODE_AUDIOFASTFORWARD => SC.audio_fastforward,
        c.SDL_SCANCODE_MEDIASELECT => SC.media_select,
        c.SDL_SCANCODE_WWW => SC.www,
        c.SDL_SCANCODE_MAIL => SC.mail,
        c.SDL_SCANCODE_CALCULATOR => SC.calculator,
        c.SDL_SCANCODE_COMPUTER => SC.computer,
        c.SDL_SCANCODE_AC_SEARCH => SC.ac_search,
        c.SDL_SCANCODE_AC_HOME => SC.ac_home,
        c.SDL_SCANCODE_AC_BACK => SC.ac_back,
        c.SDL_SCANCODE_AC_FORWARD => SC.ac_forward,
        c.SDL_SCANCODE_AC_STOP => SC.ac_stop,
        c.SDL_SCANCODE_AC_REFRESH => SC.ac_refresh,
        c.SDL_SCANCODE_AC_BOOKMARKS => SC.ac_bookmarks,
        c.SDL_SCANCODE_BRIGHTNESSDOWN => SC.brightness_down,
        c.SDL_SCANCODE_BRIGHTNESSUP => SC.brightness_up,
        c.SDL_SCANCODE_DISPLAYSWITCH => SC.displayswitch,
        c.SDL_SCANCODE_KBDILLUMTOGGLE => SC.kbdillumtoggle,
        c.SDL_SCANCODE_KBDILLUMDOWN => SC.kbdillumdown,
        c.SDL_SCANCODE_KBDILLUMUP => SC.kbdillumup,
        c.SDL_SCANCODE_EJECT => SC.eject,
        c.SDL_SCANCODE_SLEEP => SC.sleep,
        c.SDL_SCANCODE_APP1 => SC.app1,
        c.SDL_SCANCODE_APP2 => SC.app2,
        else => null,
    };
}

pub fn loadOpenGlFunction(_: void, function: [:0]const u8) ?*const anyopaque {
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

pub const WebSocket = struct {
    connected: bool = false,

    pub const State = enum {
        connecting,
        open,
        closed,
        @"error",
    };

    pub fn create(server: []const u8, protocols: []const []const u8) !WebSocket {
        _ = server;
        _ = protocols;

        return WebSocket{};
    }

    pub fn destroy(self: *WebSocket) void {
        self.* = undefined;
    }

    pub fn send(self: *WebSocket, binary: bool, message: []const u8) !void {
        _ = self;
        _ = binary;
        _ = message;
    }

    pub fn receive(self: *WebSocket) !?Event {
        if (self.connected) {
            return null;
        }
        self.connected = true;
        return .connected;
    }

    pub const Event = union(enum) {
        @"error",
        closed,
        connected,
        message: Message,
    };

    pub const Message = struct {
        allocator: std.mem.Allocator,
        data: []const u8,
        is_binary: bool,

        pub fn deinit(self: *Message) void {
            self.allocator.free(self.data);
            self.* = undefined;
        }
    };
};
