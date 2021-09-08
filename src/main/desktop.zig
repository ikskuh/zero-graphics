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
                c.SDL_KEYDOWN => if (event.key.repeat == 0) {
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

fn translateSdlScancode(scancode: c.SDL_Scancode) ?zerog.Input.Scancode {
    const SC = zerog.Input.Scancode;
    return switch (scancode) {
        .SDL_SCANCODE_A => SC.a,
        .SDL_SCANCODE_B => SC.b,
        .SDL_SCANCODE_C => SC.c,
        .SDL_SCANCODE_D => SC.d,
        .SDL_SCANCODE_E => SC.e,
        .SDL_SCANCODE_F => SC.f,
        .SDL_SCANCODE_G => SC.g,
        .SDL_SCANCODE_H => SC.h,
        .SDL_SCANCODE_I => SC.i,
        .SDL_SCANCODE_J => SC.j,
        .SDL_SCANCODE_K => SC.k,
        .SDL_SCANCODE_L => SC.l,
        .SDL_SCANCODE_M => SC.m,
        .SDL_SCANCODE_N => SC.n,
        .SDL_SCANCODE_O => SC.o,
        .SDL_SCANCODE_P => SC.p,
        .SDL_SCANCODE_Q => SC.q,
        .SDL_SCANCODE_R => SC.r,
        .SDL_SCANCODE_S => SC.s,
        .SDL_SCANCODE_T => SC.t,
        .SDL_SCANCODE_U => SC.u,
        .SDL_SCANCODE_V => SC.v,
        .SDL_SCANCODE_W => SC.w,
        .SDL_SCANCODE_X => SC.x,
        .SDL_SCANCODE_Y => SC.y,
        .SDL_SCANCODE_Z => SC.z,
        .SDL_SCANCODE_1 => SC.@"1",
        .SDL_SCANCODE_2 => SC.@"2",
        .SDL_SCANCODE_3 => SC.@"3",
        .SDL_SCANCODE_4 => SC.@"4",
        .SDL_SCANCODE_5 => SC.@"5",
        .SDL_SCANCODE_6 => SC.@"6",
        .SDL_SCANCODE_7 => SC.@"7",
        .SDL_SCANCODE_8 => SC.@"8",
        .SDL_SCANCODE_9 => SC.@"9",
        .SDL_SCANCODE_0 => SC.@"0",
        .SDL_SCANCODE_RETURN => SC.@"return",
        .SDL_SCANCODE_ESCAPE => SC.escape,
        .SDL_SCANCODE_BACKSPACE => SC.backspace,
        .SDL_SCANCODE_TAB => SC.tab,
        .SDL_SCANCODE_SPACE => SC.space,
        .SDL_SCANCODE_MINUS => SC.minus,
        .SDL_SCANCODE_EQUALS => SC.equals,
        .SDL_SCANCODE_LEFTBRACKET => SC.left_bracket,
        .SDL_SCANCODE_RIGHTBRACKET => SC.right_bracket,
        .SDL_SCANCODE_BACKSLASH => SC.backslash,
        .SDL_SCANCODE_NONUSHASH => SC.nonushash,
        .SDL_SCANCODE_SEMICOLON => SC.semicolon,
        .SDL_SCANCODE_APOSTROPHE => SC.apostrophe,
        .SDL_SCANCODE_GRAVE => SC.grave,
        .SDL_SCANCODE_COMMA => SC.comma,
        .SDL_SCANCODE_PERIOD => SC.period,
        .SDL_SCANCODE_SLASH => SC.slash,
        .SDL_SCANCODE_CAPSLOCK => SC.caps_lock,
        .SDL_SCANCODE_PRINTSCREEN => SC.print_screen,
        .SDL_SCANCODE_SCROLLLOCK => SC.scroll_lock,
        .SDL_SCANCODE_PAUSE => SC.pause,
        .SDL_SCANCODE_INSERT => SC.insert,
        .SDL_SCANCODE_HOME => SC.home,
        .SDL_SCANCODE_PAGEUP => SC.page_up,
        .SDL_SCANCODE_DELETE => SC.delete,
        .SDL_SCANCODE_END => SC.end,
        .SDL_SCANCODE_PAGEDOWN => SC.page_down,
        .SDL_SCANCODE_RIGHT => SC.right,
        .SDL_SCANCODE_LEFT => SC.left,
        .SDL_SCANCODE_DOWN => SC.down,
        .SDL_SCANCODE_UP => SC.up,
        .SDL_SCANCODE_NUMLOCKCLEAR => SC.num_lock_clear,
        .SDL_SCANCODE_KP_DIVIDE => SC.keypad_divide,
        .SDL_SCANCODE_KP_MULTIPLY => SC.keypad_multiply,
        .SDL_SCANCODE_KP_MINUS => SC.keypad_minus,
        .SDL_SCANCODE_KP_PLUS => SC.keypad_plus,
        .SDL_SCANCODE_KP_ENTER => SC.keypad_enter,
        .SDL_SCANCODE_KP_1 => SC.keypad_1,
        .SDL_SCANCODE_KP_2 => SC.keypad_2,
        .SDL_SCANCODE_KP_3 => SC.keypad_3,
        .SDL_SCANCODE_KP_4 => SC.keypad_4,
        .SDL_SCANCODE_KP_5 => SC.keypad_5,
        .SDL_SCANCODE_KP_6 => SC.keypad_6,
        .SDL_SCANCODE_KP_7 => SC.keypad_7,
        .SDL_SCANCODE_KP_8 => SC.keypad_8,
        .SDL_SCANCODE_KP_9 => SC.keypad_9,
        .SDL_SCANCODE_KP_0 => SC.keypad_0,
        .SDL_SCANCODE_KP_00 => SC.keypad_00,
        .SDL_SCANCODE_KP_000 => SC.keypad_000,
        .SDL_SCANCODE_KP_PERIOD => SC.keypad_period,
        .SDL_SCANCODE_KP_COMMA => SC.keypad_comma,
        .SDL_SCANCODE_KP_EQUALSAS400 => SC.keypad_equalsas400,
        .SDL_SCANCODE_KP_LEFTPAREN => SC.keypad_leftparen,
        .SDL_SCANCODE_KP_RIGHTPAREN => SC.keypad_rightparen,
        .SDL_SCANCODE_KP_LEFTBRACE => SC.keypad_leftbrace,
        .SDL_SCANCODE_KP_RIGHTBRACE => SC.keypad_rightbrace,
        .SDL_SCANCODE_KP_TAB => SC.keypad_tab,
        .SDL_SCANCODE_KP_BACKSPACE => SC.keypad_backspace,
        .SDL_SCANCODE_KP_A => SC.keypad_a,
        .SDL_SCANCODE_KP_B => SC.keypad_b,
        .SDL_SCANCODE_KP_C => SC.keypad_c,
        .SDL_SCANCODE_KP_D => SC.keypad_d,
        .SDL_SCANCODE_KP_E => SC.keypad_e,
        .SDL_SCANCODE_KP_F => SC.keypad_f,
        .SDL_SCANCODE_KP_XOR => SC.keypad_xor,
        .SDL_SCANCODE_KP_POWER => SC.keypad_power,
        .SDL_SCANCODE_KP_PERCENT => SC.keypad_percent,
        .SDL_SCANCODE_KP_LESS => SC.keypad_less,
        .SDL_SCANCODE_KP_GREATER => SC.keypad_greater,
        .SDL_SCANCODE_KP_AMPERSAND => SC.keypad_ampersand,
        .SDL_SCANCODE_KP_DBLAMPERSAND => SC.keypad_dblampersand,
        .SDL_SCANCODE_KP_VERTICALBAR => SC.keypad_verticalbar,
        .SDL_SCANCODE_KP_DBLVERTICALBAR => SC.keypad_dblverticalbar,
        .SDL_SCANCODE_KP_COLON => SC.keypad_colon,
        .SDL_SCANCODE_KP_HASH => SC.keypad_hash,
        .SDL_SCANCODE_KP_SPACE => SC.keypad_space,
        .SDL_SCANCODE_KP_AT => SC.keypad_at,
        .SDL_SCANCODE_KP_EXCLAM => SC.keypad_exclam,
        .SDL_SCANCODE_KP_MEMSTORE => SC.keypad_memstore,
        .SDL_SCANCODE_KP_MEMRECALL => SC.keypad_memrecall,
        .SDL_SCANCODE_KP_MEMCLEAR => SC.keypad_memclear,
        .SDL_SCANCODE_KP_MEMADD => SC.keypad_memadd,
        .SDL_SCANCODE_KP_MEMSUBTRACT => SC.keypad_memsubtract,
        .SDL_SCANCODE_KP_MEMMULTIPLY => SC.keypad_memmultiply,
        .SDL_SCANCODE_KP_MEMDIVIDE => SC.keypad_memdivide,
        .SDL_SCANCODE_KP_PLUSMINUS => SC.keypad_plusminus,
        .SDL_SCANCODE_KP_CLEAR => SC.keypad_clear,
        .SDL_SCANCODE_KP_CLEARENTRY => SC.keypad_clearentry,
        .SDL_SCANCODE_KP_BINARY => SC.keypad_binary,
        .SDL_SCANCODE_KP_OCTAL => SC.keypad_octal,
        .SDL_SCANCODE_KP_DECIMAL => SC.keypad_decimal,
        .SDL_SCANCODE_KP_HEXADECIMAL => SC.keypad_hexadecimal,
        .SDL_SCANCODE_KP_EQUALS => SC.keypad_equals,
        .SDL_SCANCODE_F1 => SC.f1,
        .SDL_SCANCODE_F2 => SC.f2,
        .SDL_SCANCODE_F3 => SC.f3,
        .SDL_SCANCODE_F4 => SC.f4,
        .SDL_SCANCODE_F5 => SC.f5,
        .SDL_SCANCODE_F6 => SC.f6,
        .SDL_SCANCODE_F7 => SC.f7,
        .SDL_SCANCODE_F8 => SC.f8,
        .SDL_SCANCODE_F9 => SC.f9,
        .SDL_SCANCODE_F10 => SC.f10,
        .SDL_SCANCODE_F11 => SC.f11,
        .SDL_SCANCODE_F12 => SC.f12,
        .SDL_SCANCODE_F13 => SC.f13,
        .SDL_SCANCODE_F14 => SC.f14,
        .SDL_SCANCODE_F15 => SC.f15,
        .SDL_SCANCODE_F16 => SC.f16,
        .SDL_SCANCODE_F17 => SC.f17,
        .SDL_SCANCODE_F18 => SC.f18,
        .SDL_SCANCODE_F19 => SC.f19,
        .SDL_SCANCODE_F20 => SC.f20,
        .SDL_SCANCODE_F21 => SC.f21,
        .SDL_SCANCODE_F22 => SC.f22,
        .SDL_SCANCODE_F23 => SC.f23,
        .SDL_SCANCODE_F24 => SC.f24,
        .SDL_SCANCODE_NONUSBACKSLASH => SC.nonusbackslash,
        .SDL_SCANCODE_APPLICATION => SC.application,
        .SDL_SCANCODE_POWER => SC.power,
        .SDL_SCANCODE_EXECUTE => SC.execute,
        .SDL_SCANCODE_HELP => SC.help,
        .SDL_SCANCODE_MENU => SC.menu,
        .SDL_SCANCODE_SELECT => SC.select,
        .SDL_SCANCODE_STOP => SC.stop,
        .SDL_SCANCODE_AGAIN => SC.again,
        .SDL_SCANCODE_UNDO => SC.undo,
        .SDL_SCANCODE_CUT => SC.cut,
        .SDL_SCANCODE_COPY => SC.copy,
        .SDL_SCANCODE_PASTE => SC.paste,
        .SDL_SCANCODE_FIND => SC.find,
        .SDL_SCANCODE_MUTE => SC.mute,
        .SDL_SCANCODE_VOLUMEUP => SC.volumeup,
        .SDL_SCANCODE_VOLUMEDOWN => SC.volumedown,
        .SDL_SCANCODE_ALTERASE => SC.alterase,
        .SDL_SCANCODE_SYSREQ => SC.sysreq,
        .SDL_SCANCODE_CANCEL => SC.cancel,
        .SDL_SCANCODE_CLEAR => SC.clear,
        .SDL_SCANCODE_PRIOR => SC.prior,
        .SDL_SCANCODE_RETURN2 => SC.return2,
        .SDL_SCANCODE_SEPARATOR => SC.separator,
        .SDL_SCANCODE_OUT => SC.out,
        .SDL_SCANCODE_OPER => SC.oper,
        .SDL_SCANCODE_CLEARAGAIN => SC.clearagain,
        .SDL_SCANCODE_CRSEL => SC.crsel,
        .SDL_SCANCODE_EXSEL => SC.exsel,
        .SDL_SCANCODE_THOUSANDSSEPARATOR => SC.thousandsseparator,
        .SDL_SCANCODE_DECIMALSEPARATOR => SC.decimalseparator,
        .SDL_SCANCODE_CURRENCYUNIT => SC.currencyunit,
        .SDL_SCANCODE_CURRENCYSUBUNIT => SC.currencysubunit,
        .SDL_SCANCODE_LCTRL => SC.ctrl_left,
        .SDL_SCANCODE_LSHIFT => SC.shift_left,
        .SDL_SCANCODE_LALT => SC.alt_left,
        .SDL_SCANCODE_LGUI => SC.gui_left,
        .SDL_SCANCODE_RCTRL => SC.ctrl_right,
        .SDL_SCANCODE_RSHIFT => SC.shift_right,
        .SDL_SCANCODE_RALT => SC.alt_right,
        .SDL_SCANCODE_RGUI => SC.gui_right,
        .SDL_SCANCODE_MODE => SC.mode,
        .SDL_SCANCODE_AUDIONEXT => SC.audio_next,
        .SDL_SCANCODE_AUDIOPREV => SC.audio_prev,
        .SDL_SCANCODE_AUDIOSTOP => SC.audio_stop,
        .SDL_SCANCODE_AUDIOPLAY => SC.audio_play,
        .SDL_SCANCODE_AUDIOMUTE => SC.audio_mute,
        .SDL_SCANCODE_AUDIOREWIND => SC.audio_rewind,
        .SDL_SCANCODE_AUDIOFASTFORWARD => SC.audio_fastforward,
        .SDL_SCANCODE_MEDIASELECT => SC.media_select,
        .SDL_SCANCODE_WWW => SC.www,
        .SDL_SCANCODE_MAIL => SC.mail,
        .SDL_SCANCODE_CALCULATOR => SC.calculator,
        .SDL_SCANCODE_COMPUTER => SC.computer,
        .SDL_SCANCODE_AC_SEARCH => SC.ac_search,
        .SDL_SCANCODE_AC_HOME => SC.ac_home,
        .SDL_SCANCODE_AC_BACK => SC.ac_back,
        .SDL_SCANCODE_AC_FORWARD => SC.ac_forward,
        .SDL_SCANCODE_AC_STOP => SC.ac_stop,
        .SDL_SCANCODE_AC_REFRESH => SC.ac_refresh,
        .SDL_SCANCODE_AC_BOOKMARKS => SC.ac_bookmarks,
        .SDL_SCANCODE_BRIGHTNESSDOWN => SC.brightness_down,
        .SDL_SCANCODE_BRIGHTNESSUP => SC.brightness_up,
        .SDL_SCANCODE_DISPLAYSWITCH => SC.displayswitch,
        .SDL_SCANCODE_KBDILLUMTOGGLE => SC.kbdillumtoggle,
        .SDL_SCANCODE_KBDILLUMDOWN => SC.kbdillumdown,
        .SDL_SCANCODE_KBDILLUMUP => SC.kbdillumup,
        .SDL_SCANCODE_EJECT => SC.eject,
        .SDL_SCANCODE_SLEEP => SC.sleep,
        .SDL_SCANCODE_APP1 => SC.app1,
        .SDL_SCANCODE_APP2 => SC.app2,
        else => null,
    };
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
