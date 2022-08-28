const std = @import("std");
const builtin = @import("builtin");
const logger = std.log.scoped(.wasm_backend);

const gles = @import("../gl_es_2v0.zig");
const zerog = @import("../zero-graphics.zig");
const Application = @import("application");
pub const CoreApplication = @import("../CoreApplication.zig");

comptime {
    // enforce inclusion of "extern  c" implementations
    _ = @import("common.zig");
}

var error_name_buffer: [256]u8 = undefined;

fn mapWasmError(err: anyerror) usize {
    // prevent "pointer is 0"
    _ = std.fmt.bufPrintZ(&error_name_buffer, "{s}", .{@errorName(err)}) catch "OutOfMemory";

    return 1;
}

export fn app_get_error_ptr() [*]u8 {
    return &error_name_buffer;
}

export fn app_get_error_len() usize {
    return std.mem.indexOfScalar(u8, &error_name_buffer, 0) orelse error_name_buffer.len;
}

pub const backend: zerog.Backend = .wasm;

extern fn wasm_loadOpenGlFunction(function: [*]const u8, function_len: usize) ?*anyopaque;

extern fn wasm_quit() void;
extern fn wasm_panic(ptr: [*]const u8, len: usize) void;
extern fn wasm_log_write(ptr: [*]const u8, len: usize) void;
extern fn wasm_log_flush() void;
extern "webgl" fn meta_getScreenW() u32;
extern "webgl" fn meta_getScreenH() u32;
extern fn now_f64() f64;

pub const log_level = .info;

var app_instance: CoreApplication = undefined;
var input_handler: zerog.Input = undefined;

var global_arena: std.heap.ArenaAllocator = undefined;
var gpa: std.heap.GeneralPurposeAllocator(.{
    .safety = false,
}) = undefined;

const WriteError = error{};
const LogWriter = std.io.Writer(void, WriteError, writeLog);

fn writeLog(_: void, msg: []const u8) WriteError!usize {
    wasm_log_write(msg.ptr, msg.len);
    return msg.len;
}

pub fn milliTimestamp() i64 {
    return @floatToInt(i64, now_f64());
}

pub fn getDisplayDPI() f32 {
    // TODO: Figure out if browsers can actually report the correct DPI scale
    // for the display.
    // Otherwise, keep 96 as it's the default for all browsers now?
    return 96.0;
}

/// Overwrite default log handler
pub fn log(
    comptime message_level: std.log.Level,
    comptime scope: @Type(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    const level_txt = switch (message_level) {
        .err => "error",
        .warn => "warning",
        .info => "info",
        .debug => "debug",
    };
    const prefix2 = if (scope == .default) ": " else "(" ++ @tagName(scope) ++ "): ";

    (LogWriter{ .context = {} }).print(level_txt ++ prefix2 ++ format ++ "\n", args) catch return;

    wasm_log_flush();
}

/// Overwrite default panic handler
pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace) noreturn {
    // std.log.crit("panic: {s}", .{msg});
    wasm_panic(msg.ptr, msg.len);
    unreachable;
}

pub fn loadOpenGlFunction(_: void, function: [:0]const u8) ?*const anyopaque {
    inline for (comptime std.meta.declarations(WebGL)) |decl| {
        const gl_ep = "gl" ++ [_]u8{std.ascii.toUpper(decl.name[0])} ++ decl.name[1..];
        if (std.mem.eql(u8, gl_ep, function)) {
            return @as(*const anyopaque, &@field(WebGL, decl.name));
        }
    }
    return null;
}

export fn app_init() u32 {
    global_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    gpa = .{
        .backing_allocator = global_arena.allocator(),
    };

    input_handler = zerog.Input.init(gpa.allocator());

    zerog.CodeEditor.init() catch |err| @panic(@errorName(err));

    WebSocket.global_handles = std.AutoArrayHashMap(websocket.Handle, *WebSocket.Data).init(gpa.allocator());

    app_instance.init(gpa.allocator(), &input_handler) catch |err| @panic(@errorName(err));

    gles.load({}, loadOpenGlFunction) catch |err| @panic(@errorName(err));

    app_instance.setupGraphics() catch |err| @panic(@errorName(err));

    app_instance.resize(@intCast(u15, meta_getScreenW()), @intCast(u15, meta_getScreenH())) catch return 2;

    return 0;
}

fn logInputError(err: error{ OutOfMemory, Utf8CannotEncodeSurrogateHalf, CodepointTooLarge }) void {
    std.log.err("Failed to process input event: {s}", .{@errorName(err)});
}

const JS_BUTTON_LEFT = 0;
const JS_BUTTON_MIDDLE = 1;
const JS_BUTTON_RIGHT = 2;

export fn app_input_sendMouseDown(x: i16, y: i16, button: u8) void {
    _ = x;
    _ = y;
    switch (button) {
        JS_BUTTON_LEFT => input_handler.pushEvent(.{ .pointer_press = .primary }) catch |e| logInputError(e),
        JS_BUTTON_RIGHT => input_handler.pushEvent(.{ .pointer_press = .secondary }) catch |e| logInputError(e),
        else => {},
    }
}

export fn app_input_sendMouseUp(x: i16, y: i16, button: u8) void {
    _ = x;
    _ = y;
    switch (button) {
        JS_BUTTON_LEFT => input_handler.pushEvent(.{ .pointer_release = .primary }) catch |e| logInputError(e),
        JS_BUTTON_RIGHT => input_handler.pushEvent(.{ .pointer_release = .secondary }) catch |e| logInputError(e),
        else => {},
    }
}

export fn app_input_sendMouseMotion(x: i16, y: i16) void {
    input_handler.pushEvent(.{ .pointer_motion = .{
        .x = @floatToInt(i16, @intToFloat(f32, x)),
        .y = @floatToInt(i16, @intToFloat(f32, y)),
    } }) catch |e| logInputError(e);
}

fn translateJsScancode(js_scancode: u32) ?zerog.Input.Scancode {
    const SC = zerog.Input.Scancode;
    return switch (js_scancode) {
        1 => SC.a,
        2 => SC.b,
        3 => SC.c,
        4 => SC.d,
        5 => SC.e,
        6 => SC.f,
        7 => SC.g,
        8 => SC.h,
        9 => SC.i,
        10 => SC.j,
        11 => SC.k,
        12 => SC.l,
        13 => SC.m,
        14 => SC.n,
        15 => SC.o,
        16 => SC.p,
        17 => SC.q,
        18 => SC.r,
        19 => SC.s,
        20 => SC.t,
        21 => SC.u,
        22 => SC.v,
        23 => SC.w,
        24 => SC.x,
        25 => SC.y,
        26 => SC.z,
        27 => SC.@"1",
        28 => SC.@"2",
        29 => SC.@"3",
        30 => SC.@"4",
        31 => SC.@"5",
        32 => SC.@"6",
        33 => SC.@"7",
        34 => SC.@"8",
        35 => SC.@"9",
        36 => SC.@"0",
        37 => SC.@"return",
        38 => SC.escape,
        39 => SC.backspace,
        40 => SC.tab,
        41 => SC.space,
        42 => SC.minus,
        43 => SC.equals,
        44 => SC.left_bracket,
        45 => SC.right_bracket,
        46 => SC.backslash,
        47 => SC.nonushash,
        48 => SC.semicolon,
        49 => SC.apostrophe,
        50 => SC.grave,
        51 => SC.comma,
        52 => SC.period,
        53 => SC.slash,
        54 => SC.caps_lock,
        55 => SC.print_screen,
        56 => SC.scroll_lock,
        57 => SC.pause,
        58 => SC.insert,
        59 => SC.home,
        60 => SC.page_up,
        61 => SC.delete,
        62 => SC.end,
        63 => SC.page_down,
        64 => SC.right,
        65 => SC.left,
        66 => SC.down,
        67 => SC.up,
        68 => SC.num_lock_clear,
        69 => SC.keypad_divide,
        70 => SC.keypad_multiply,
        71 => SC.keypad_minus,
        72 => SC.keypad_plus,
        73 => SC.keypad_enter,
        74 => SC.keypad_1,
        75 => SC.keypad_2,
        76 => SC.keypad_3,
        77 => SC.keypad_4,
        78 => SC.keypad_5,
        79 => SC.keypad_6,
        80 => SC.keypad_7,
        81 => SC.keypad_8,
        82 => SC.keypad_9,
        83 => SC.keypad_0,
        84 => SC.keypad_00,
        85 => SC.keypad_000,
        86 => SC.keypad_period,
        87 => SC.keypad_comma,
        88 => SC.keypad_equalsas400,
        89 => SC.keypad_leftparen,
        90 => SC.keypad_rightparen,
        91 => SC.keypad_leftbrace,
        92 => SC.keypad_rightbrace,
        93 => SC.keypad_tab,
        94 => SC.keypad_backspace,
        95 => SC.keypad_a,
        96 => SC.keypad_b,
        97 => SC.keypad_c,
        98 => SC.keypad_d,
        99 => SC.keypad_e,
        100 => SC.keypad_f,
        101 => SC.keypad_xor,
        102 => SC.keypad_power,
        103 => SC.keypad_percent,
        104 => SC.keypad_less,
        105 => SC.keypad_greater,
        106 => SC.keypad_ampersand,
        107 => SC.keypad_dblampersand,
        108 => SC.keypad_verticalbar,
        109 => SC.keypad_dblverticalbar,
        110 => SC.keypad_colon,
        111 => SC.keypad_hash,
        112 => SC.keypad_space,
        113 => SC.keypad_at,
        114 => SC.keypad_exclam,
        115 => SC.keypad_memstore,
        116 => SC.keypad_memrecall,
        117 => SC.keypad_memclear,
        118 => SC.keypad_memadd,
        119 => SC.keypad_memsubtract,
        120 => SC.keypad_memmultiply,
        121 => SC.keypad_memdivide,
        122 => SC.keypad_plusminus,
        123 => SC.keypad_clear,
        124 => SC.keypad_clearentry,
        125 => SC.keypad_binary,
        126 => SC.keypad_octal,
        127 => SC.keypad_decimal,
        128 => SC.keypad_hexadecimal,
        129 => SC.keypad_equals,
        130 => SC.f1,
        131 => SC.f2,
        132 => SC.f3,
        133 => SC.f4,
        134 => SC.f5,
        135 => SC.f6,
        136 => SC.f7,
        137 => SC.f8,
        138 => SC.f9,
        139 => SC.f10,
        140 => SC.f11,
        141 => SC.f12,
        142 => SC.f13,
        143 => SC.f14,
        144 => SC.f15,
        145 => SC.f16,
        146 => SC.f17,
        147 => SC.f18,
        148 => SC.f19,
        149 => SC.f20,
        150 => SC.f21,
        151 => SC.f22,
        152 => SC.f23,
        153 => SC.f24,
        154 => SC.nonusbackslash,
        155 => SC.application,
        156 => SC.power,
        157 => SC.execute,
        158 => SC.help,
        159 => SC.menu,
        160 => SC.select,
        161 => SC.stop,
        162 => SC.again,
        163 => SC.undo,
        164 => SC.cut,
        165 => SC.copy,
        166 => SC.paste,
        167 => SC.find,
        168 => SC.mute,
        169 => SC.volumeup,
        170 => SC.volumedown,
        171 => SC.alterase,
        172 => SC.sysreq,
        173 => SC.cancel,
        174 => SC.clear,
        175 => SC.prior,
        176 => SC.return2,
        177 => SC.separator,
        178 => SC.out,
        179 => SC.oper,
        180 => SC.clearagain,
        181 => SC.crsel,
        182 => SC.exsel,
        183 => SC.thousandsseparator,
        184 => SC.decimalseparator,
        185 => SC.currencyunit,
        186 => SC.currencysubunit,
        187 => SC.ctrl_left,
        188 => SC.shift_left,
        189 => SC.alt_left,
        190 => SC.gui_left,
        191 => SC.ctrl_right,
        192 => SC.shift_right,
        193 => SC.alt_right,
        194 => SC.gui_right,
        195 => SC.mode,
        196 => SC.audio_next,
        197 => SC.audio_prev,
        198 => SC.audio_stop,
        199 => SC.audio_play,
        200 => SC.audio_mute,
        201 => SC.audio_rewind,
        202 => SC.audio_fastforward,
        203 => SC.media_select,
        204 => SC.www,
        205 => SC.mail,
        206 => SC.calculator,
        207 => SC.computer,
        208 => SC.ac_search,
        209 => SC.ac_home,
        210 => SC.ac_back,
        211 => SC.ac_forward,
        212 => SC.ac_stop,
        213 => SC.ac_refresh,
        214 => SC.ac_bookmarks,
        215 => SC.brightness_down,
        216 => SC.brightness_up,
        217 => SC.displayswitch,
        218 => SC.kbdillumtoggle,
        219 => SC.kbdillumdown,
        220 => SC.kbdillumup,
        221 => SC.eject,
        222 => SC.sleep,
        223 => SC.app1,
        224 => SC.app2,
        else => blk: {
            if (builtin.mode == .Debug) {
                std.log.info("Unknown javascript scancode: {}", .{js_scancode});
            }
            break :blk null;
        },
    };
}

export fn app_input_sendKeyDown(js_scancode: u32) void {
    if (translateJsScancode(js_scancode)) |scancode| {
        input_handler.pushEvent(.{ .key_down = scancode }) catch |err| logInputError(err);
    }
}

export fn app_input_sendKeyUp(js_scancode: u32) void {
    if (translateJsScancode(js_scancode)) |scancode| {
        input_handler.pushEvent(.{ .key_up = scancode }) catch |err| logInputError(err);
    }
}

export fn app_input_sendTextInput(codepoint: u32, shift: bool, alt: bool, ctrl: bool, super: bool) void {
    var buf_str: [8]u8 = undefined;

    const buf_len = std.unicode.utf8Encode(@truncate(u21, codepoint), &buf_str) catch |err| {
        logInputError(err);
        return;
    };

    input_handler.pushEvent(.{ .text_input = .{
        .text = buf_str[0..buf_len],
        .modifiers = .{
            .shift = shift,
            .alt = alt,
            .ctrl = ctrl,
            .super = super,
        },
    } }) catch |err| logInputError(err);
}

var last_width: u15 = 0;
var last_height: u15 = 0;

export fn app_update() usize {
    const screen_width = @intCast(u15, meta_getScreenW());
    const screen_height = @intCast(u15, meta_getScreenH());

    if (screen_width != last_width or screen_height != last_height) {
        app_instance.resize(screen_width, screen_height) catch |e| return mapWasmError(e);
        last_width = screen_width;
        last_height = screen_height;
    }

    const res = app_instance.update() catch |e| return mapWasmError(e);
    if (!res)
        wasm_quit();
    app_instance.render() catch |e| return mapWasmError(e);
    return 0;
}

export fn app_deinit() u32 {
    app_instance.teardownGraphics();
    app_instance.deinit();
    input_handler.deinit();

    zerog.CodeEditor.deinit();

    // _ = gpa.deinit();
    global_arena.deinit();

    return 0;
}

fn unknownOpenGlFunction() void {
    @panic("tried to use unknown opengl function!");
}

const GLuint = gles.GLuint;
const GLenum = gles.GLenum;
const GLfloat = gles.GLfloat;
const GLchar = gles.GLchar;
const GLint = gles.GLint;
const GLboolean = gles.GLboolean;
const GLsizei = gles.GLsizei;
const GLintptr = gles.GLintptr;
const GLubyte = gles.GLubyte;
const GLsizeiptr = gles.GLsizeiptr;
const WebGL = struct {
    pub extern "webgl" fn activeTexture(target: c_uint) void;
    pub extern "webgl" fn attachShader(program: c_uint, shader: c_uint) void;
    pub extern "webgl" fn bindBuffer(type: c_uint, buffer_id: c_uint) void;
    pub extern "webgl" fn bindVertexArray(vertex_array_id: c_uint) void;
    pub extern "webgl" fn bindFramebuffer(target: c_uint, framebuffer: c_uint) void;
    pub extern "webgl" fn bindTexture(target: c_uint, texture_id: c_uint) void;
    pub extern "webgl" fn blendFunc(x: c_uint, y: c_uint) void;
    pub extern "webgl" fn bufferData(type: c_uint, count: c_long, data_ptr: ?*const anyopaque, draw_type: c_uint) void;
    pub extern "webgl" fn checkFramebufferStatus(target: gles.GLenum) gles.GLenum;
    pub extern "webgl" fn clear(mask: gles.GLbitfield) void;
    pub extern "webgl" fn clearColor(r: f32, g: f32, b: f32, a: f32) void;
    pub extern "webgl" fn compileShader(shader: gles.GLuint) void;
    // pub extern fn getShaderCompileStatus(shader: gles.GLuint) GLboolean;
    pub extern "webgl" fn getShaderiv(_shader: gles.GLuint, _pname: gles.GLenum, _params: [*c]gles.GLint) void;
    pub extern "webgl" fn getProgramiv(_program: gles.GLuint, _pname: gles.GLenum, _params: [*c]gles.GLint) void;
    pub extern "webgl" fn genBuffers(_n: gles.GLsizei, _buffers: [*c]gles.GLuint) void;
    pub extern "webgl" fn createFramebuffer() gles.GLuint;
    pub extern "webgl" fn createProgram() gles.GLuint;
    pub extern "webgl" fn createShader(shader_type: gles.GLenum) gles.GLuint;
    pub extern "webgl" fn genTextures(count: gles.GLsizei, textures: [*c]gles.GLuint) void;
    pub extern "webgl" fn deleteBuffers(count: gles.GLsizei, id: [*c]const gles.GLuint) void;
    pub extern "webgl" fn deleteProgram(id: c_uint) void;
    pub extern "webgl" fn deleteShader(id: c_uint) void;
    pub extern "webgl" fn deleteTexture(id: c_uint) void;
    pub extern "webgl" fn deleteVertexArrays(count: gles.GLsizei, id: [*c]const gles.GLuint) void;
    pub extern "webgl" fn depthFunc(x: c_uint) void;
    pub extern "webgl" fn detachShader(program: c_uint, shader: c_uint) void;
    pub extern "webgl" fn disable(cap: gles.GLenum) void;
    pub extern "webgl" fn genVertexArrays(_n: gles.GLsizei, _arrays: [*c]gles.GLuint) void;
    pub extern "webgl" fn drawArrays(type: c_uint, offset: c_uint, count: c_int) void;
    pub extern "webgl" fn drawElements(mode: gles.GLenum, count: gles.GLsizei, type: gles.GLenum, offset: ?*const anyopaque) void;
    pub extern "webgl" fn enable(x: c_uint) void;
    pub extern "webgl" fn enableVertexAttribArray(x: c_uint) void;
    pub extern "webgl" fn framebufferTexture2D(target: gles.GLenum, attachment: gles.GLenum, textarget: gles.GLenum, texture: gles.GLuint, level: gles.GLint) void;
    pub extern "webgl" fn frontFace(mode: gles.GLenum) void;
    pub extern "webgl" fn cullFace(face: gles.GLenum) void;
    extern "webgl" fn getAttribLocation_(program_id: c_uint, name_ptr: [*]const u8, name_len: c_uint) c_int;
    pub fn getAttribLocation(program_id: c_uint, name_ptr: [*:0]const u8) callconv(.C) c_int {
        const name = std.mem.span(name_ptr);
        return getAttribLocation_(program_id, name.ptr, name.len);
    }
    pub extern "webgl" fn getError() c_int;
    pub extern "webgl" fn getShaderInfoLog(shader: gles.GLuint, maxLength: gles.GLsizei, length: ?*gles.GLsizei, infoLog: ?[*]u8) void;
    extern "webgl" fn getUniformLocation_(program_id: c_uint, name_ptr: [*]const u8, name_len: c_uint) c_int;
    pub fn getUniformLocation(program_id: c_uint, name_ptr: [*:0]const u8) c_int {
        const name = std.mem.span(name_ptr);
        return getUniformLocation_(program_id, name.ptr, name.len);
    }
    pub extern "webgl" fn linkProgram(program: c_uint) void;
    // pub extern fn getProgramLinkStatus(program: c_uint) gles.GLboolean;
    pub extern "webgl" fn getProgramInfoLog(program: gles.GLuint, maxLength: gles.GLsizei, length: ?*gles.GLsizei, infoLog: ?[*]u8) void;
    pub extern "webgl" fn pixelStorei(pname: gles.GLenum, param: gles.GLint) void;
    pub extern "webgl" fn shaderSource(shader: gles.GLuint, count: gles.GLsizei, string: [*c]const [*c]const gles.GLchar, length: [*c]const gles.GLint) void;
    pub extern "webgl" fn texImage2D(target: c_uint, level: c_uint, internal_format: c_uint, width: c_int, height: c_int, border: c_uint, format: c_uint, type: c_uint, data_ptr: ?[*]const u8) void;
    pub extern "webgl" fn texParameterf(target: c_uint, pname: c_uint, param: f32) void;
    pub extern "webgl" fn texParameteri(target: c_uint, pname: c_uint, param: c_uint) void;
    pub extern "webgl" fn uniform1f(location_id: c_int, x: f32) void;
    pub extern "webgl" fn uniform1i(location_id: c_int, x: c_int) void;
    pub extern "webgl" fn uniform4f(location_id: c_int, x: f32, y: f32, z: f32, w: f32) void;
    pub extern "webgl" fn uniformMatrix4fv(location_id: c_int, data_len: c_int, transpose: c_uint, data_ptr: [*]const f32) void;
    pub extern "webgl" fn useProgram(program_id: c_uint) void;
    pub extern "webgl" fn vertexAttribPointer(attrib_location: c_uint, size: c_uint, type: c_uint, normalize: c_uint, stride: c_uint, offset: ?*const anyopaque) void;
    pub extern "webgl" fn viewport(x: c_int, y: c_int, width: c_int, height: c_int) void;
    pub extern "webgl" fn scissor(x: gles.GLint, y: gles.GLint, width: gles.GLsizei, height: gles.GLsizei) void;

    extern "webgl" fn blendEquation(_mode: GLenum) callconv(.C) void;

    pub extern "webgl" fn getStringJs(name: GLenum) void;
    fn getString(name: GLenum) callconv(.C) ?[*:0]const GLubyte {
        const String = struct {
            var memory: ?[:0]u8 = null;

            export fn getString_alloc(size: u32) [*]u8 {
                if (memory) |old| {
                    gpa.allocator().free(old);
                    memory = null;
                }
                memory = gpa.allocator().allocSentinel(u8, size, 0) catch @panic("out of memory!");
                return memory.?.ptr;
            }
        };

        getStringJs(name);

        return String.memory.?.ptr;
    }
    extern "webgl" fn uniform2i(_location: GLint, _v0: GLint, _v1: GLint) callconv(.C) void;

    extern "webgl" fn hint(_target: GLenum, _mode: GLenum) void;

    extern "webgl" fn bindAttribLocationJs(_program: GLuint, _index: GLuint, _name: [*]const GLchar, name_len: usize) void;
    fn bindAttribLocation(_program: GLuint, _index: GLuint, _name: [*c]const GLchar) callconv(.C) void {
        bindAttribLocationJs(_program, _index, _name, std.mem.len(@as([*:0]const u8, _name)));
    }

    extern "webgl" fn bindRenderbuffer(_target: GLenum, _renderbuffer: GLuint) void;
    extern "webgl" fn blendColor(_red: GLfloat, _green: GLfloat, _blue: GLfloat, _alpha: GLfloat) void;
    extern "webgl" fn blendEquationSeparate(_modeRGB: GLenum, _modeAlpha: GLenum) void;
    extern "webgl" fn blendFuncSeparate(_sfactorRGB: GLenum, _dfactorRGB: GLenum, _sfactorAlpha: GLenum, _dfactorAlpha: GLenum) void;
    extern "webgl" fn bufferSubData(_target: GLenum, _offset: GLintptr, _size: GLsizeiptr, _data: ?*const anyopaque) void;
    extern "webgl" fn clearDepthf(_d: GLfloat) void;
    extern "webgl" fn clearStencil(_s: GLint) void;
    extern "webgl" fn colorMask(_red: GLboolean, _green: GLboolean, _blue: GLboolean, _alpha: GLboolean) void;
    extern "webgl" fn compressedTexImage2D(_target: GLenum, _level: GLint, _internalformat: GLenum, _width: GLsizei, _height: GLsizei, _border: GLint, _imageSize: GLsizei, _data: ?*const anyopaque) void;
    extern "webgl" fn compressedTexSubImage2D(_target: GLenum, _level: GLint, _xoffset: GLint, _yoffset: GLint, _width: GLsizei, _height: GLsizei, _format: GLenum, _imageSize: GLsizei, _data: ?*const anyopaque) void;
    extern "webgl" fn copyTexImage2D(_target: GLenum, _level: GLint, _internalformat: GLenum, _x: GLint, _y: GLint, _width: GLsizei, _height: GLsizei, _border: GLint) void;
    extern "webgl" fn copyTexSubImage2D(_target: GLenum, _level: GLint, _xoffset: GLint, _yoffset: GLint, _x: GLint, _y: GLint, _width: GLsizei, _height: GLsizei) void;
    extern "webgl" fn deleteFramebuffers(_n: GLsizei, _framebuffers: [*c]const GLuint) void;
    extern "webgl" fn deleteRenderbuffers(_n: GLsizei, _renderbuffers: [*c]const GLuint) void;
    extern "webgl" fn deleteTextures(_n: GLsizei, _textures: [*c]const GLuint) void;
    extern "webgl" fn depthMask(_flag: GLboolean) void;
    extern "webgl" fn depthRangef(_n: GLfloat, _f: GLfloat) void;
    extern "webgl" fn disableVertexAttribArray(_index: GLuint) void;
    extern "webgl" fn finish() void;
    extern "webgl" fn flush() void;
    extern "webgl" fn framebufferRenderbuffer(_target: GLenum, _attachment: GLenum, _renderbuffertarget: GLenum, _renderbuffer: GLuint) void;
    extern "webgl" fn generateMipmap(_target: GLenum) void;
    extern "webgl" fn genFramebuffers(_n: GLsizei, _framebuffers: [*c]GLuint) void;
    extern "webgl" fn genRenderbuffers(_n: GLsizei, _renderbuffers: [*c]GLuint) void;
    extern "webgl" fn getActiveAttrib(_program: GLuint, _index: GLuint, _bufSize: GLsizei, _length: [*c]GLsizei, _size: [*c]GLint, _type: [*c]GLenum, _name: [*c]GLchar) void;
    extern "webgl" fn getActiveUniform(_program: GLuint, _index: GLuint, _bufSize: GLsizei, _length: [*c]GLsizei, _size: [*c]GLint, _type: [*c]GLenum, _name: [*c]GLchar) void;
    extern "webgl" fn getAttachedShaders(_program: GLuint, _maxCount: GLsizei, _count: [*c]GLsizei, _shaders: [*c]GLuint) void;
    extern "webgl" fn getBooleanv(_pname: GLenum, _data: [*c]GLboolean) void;
    extern "webgl" fn getBufferParameteriv(_target: GLenum, _pname: GLenum, _params: [*c]GLint) void;
    extern "webgl" fn getFloatv(_pname: GLenum, _data: [*c]GLfloat) void;
    extern "webgl" fn getFramebufferAttachmentParameteriv(_target: GLenum, _attachment: GLenum, _pname: GLenum, _params: [*c]GLint) void;
    extern "webgl" fn getIntegerv(_pname: GLenum, _data: [*c]GLint) void;
    extern "webgl" fn getRenderbufferParameteriv(_target: GLenum, _pname: GLenum, _params: [*c]GLint) void;
    extern "webgl" fn getShaderPrecisionFormat(_shadertype: GLenum, _precisiontype: GLenum, _range: [*c]GLint, _precision: [*c]GLint) void;
    extern "webgl" fn getShaderSource(_shader: GLuint, _bufSize: GLsizei, _length: [*c]GLsizei, _source: [*c]GLchar) void;
    extern "webgl" fn getTexParameterfv(_target: GLenum, _pname: GLenum, _params: [*c]GLfloat) void;
    extern "webgl" fn getTexParameteriv(_target: GLenum, _pname: GLenum, _params: [*c]GLint) void;
    extern "webgl" fn getUniformfv(_program: GLuint, _location: GLint, _params: [*c]GLfloat) void;
    extern "webgl" fn getUniformiv(_program: GLuint, _location: GLint, _params: [*c]GLint) void;
    extern "webgl" fn getVertexAttribfv(_index: GLuint, _pname: GLenum, _params: [*c]GLfloat) void;
    extern "webgl" fn getVertexAttribiv(_index: GLuint, _pname: GLenum, _params: [*c]GLint) void;
    extern "webgl" fn getVertexAttribPointerv(_index: GLuint, _pname: GLenum, _pointer: ?*?*anyopaque) void;
    extern "webgl" fn isBuffer(_buffer: GLuint) GLboolean;
    extern "webgl" fn isEnabled(_cap: GLenum) GLboolean;
    extern "webgl" fn isFramebuffer(_framebuffer: GLuint) GLboolean;
    extern "webgl" fn isProgram(_program: GLuint) GLboolean;
    extern "webgl" fn isRenderbuffer(_renderbuffer: GLuint) GLboolean;
    extern "webgl" fn isShader(_shader: GLuint) GLboolean;
    extern "webgl" fn isTexture(_texture: GLuint) GLboolean;
    extern "webgl" fn lineWidth(_width: GLfloat) void;
    extern "webgl" fn polygonOffset(_factor: GLfloat, _units: GLfloat) void;
    extern "webgl" fn readPixels(_x: GLint, _y: GLint, _width: GLsizei, _height: GLsizei, _format: GLenum, _type: GLenum, _pixels: ?*anyopaque) void;
    extern "webgl" fn releaseShaderCompiler() void;
    extern "webgl" fn renderbufferStorage(_target: GLenum, _internalformat: GLenum, _width: GLsizei, _height: GLsizei) void;
    extern "webgl" fn sampleCoverage(_value: GLfloat, _invert: GLboolean) void;
    extern "webgl" fn shaderBinary(_count: GLsizei, _shaders: [*c]const GLuint, _binaryFormat: GLenum, _binary: ?*const anyopaque, _length: GLsizei) void;
    extern "webgl" fn stencilFunc(_func: GLenum, _ref: GLint, _mask: GLuint) void;
    extern "webgl" fn stencilFuncSeparate(_face: GLenum, _func: GLenum, _ref: GLint, _mask: GLuint) void;
    extern "webgl" fn stencilMask(_mask: GLuint) void;
    extern "webgl" fn stencilMaskSeparate(_face: GLenum, _mask: GLuint) void;
    extern "webgl" fn stencilOp(_fail: GLenum, _zfail: GLenum, _zpass: GLenum) void;
    extern "webgl" fn stencilOpSeparate(_face: GLenum, _sfail: GLenum, _dpfail: GLenum, _dppass: GLenum) void;
    extern "webgl" fn texParameterfv(_target: GLenum, _pname: GLenum, _params: [*c]const GLfloat) void;
    extern "webgl" fn texParameteriv(_target: GLenum, _pname: GLenum, _params: [*c]const GLint) void;
    extern "webgl" fn texSubImage2D(_target: GLenum, _level: GLint, _xoffset: GLint, _yoffset: GLint, _width: GLsizei, _height: GLsizei, _format: GLenum, _type: GLenum, _pixels: ?*const anyopaque) void;
    extern "webgl" fn uniform1fv(_location: GLint, _count: GLsizei, _value: [*c]const GLfloat) void;
    extern "webgl" fn uniform1iv(_location: GLint, _count: GLsizei, _value: [*c]const GLint) void;
    extern "webgl" fn uniform2f(_location: GLint, _v0: GLfloat, _v1: GLfloat) void;
    extern "webgl" fn uniform2fv(_location: GLint, _count: GLsizei, _value: [*c]const GLfloat) void;
    extern "webgl" fn uniform2iv(_location: GLint, _count: GLsizei, _value: [*c]const GLint) void;
    extern "webgl" fn uniform3f(_location: GLint, _v0: GLfloat, _v1: GLfloat, _v2: GLfloat) void;
    extern "webgl" fn uniform3fv(_location: GLint, _count: GLsizei, _value: [*c]const GLfloat) void;
    extern "webgl" fn uniform3i(_location: GLint, _v0: GLint, _v1: GLint, _v2: GLint) void;
    extern "webgl" fn uniform3iv(_location: GLint, _count: GLsizei, _value: [*c]const GLint) void;
    extern "webgl" fn uniform4fv(_location: GLint, _count: GLsizei, _value: [*c]const GLfloat) void;
    extern "webgl" fn uniform4i(_location: GLint, _v0: GLint, _v1: GLint, _v2: GLint, _v3: GLint) void;
    extern "webgl" fn uniform4iv(_location: GLint, _count: GLsizei, _value: [*c]const GLint) void;
    extern "webgl" fn uniformMatrix2fv(_location: GLint, _count: GLsizei, _transpose: GLboolean, _value: [*c]const GLfloat) void;
    extern "webgl" fn uniformMatrix3fv(_location: GLint, _count: GLsizei, _transpose: GLboolean, _value: [*c]const GLfloat) void;
    extern "webgl" fn validateProgram(_program: GLuint) void;
    extern "webgl" fn vertexAttrib1f(_index: GLuint, _x: GLfloat) void;
    extern "webgl" fn vertexAttrib1fv(_index: GLuint, _v: [*c]const GLfloat) void;
    extern "webgl" fn vertexAttrib2f(_index: GLuint, _x: GLfloat, _y: GLfloat) void;
    extern "webgl" fn vertexAttrib2fv(_index: GLuint, _v: [*c]const GLfloat) void;
    extern "webgl" fn vertexAttrib3f(_index: GLuint, _x: GLfloat, _y: GLfloat, _z: GLfloat) void;
    extern "webgl" fn vertexAttrib3fv(_index: GLuint, _v: [*c]const GLfloat) void;
    extern "webgl" fn vertexAttrib4f(_index: GLuint, _x: GLfloat, _y: GLfloat, _z: GLfloat, _w: GLfloat) void;
    extern "webgl" fn vertexAttrib4fv(_index: GLuint, _v: [*c]const GLfloat) void;
};

pub const WebSocket = struct {
    pub const State = enum {
        connecting,
        open,
        closed,
        @"error",
    };

    const Queue = std.TailQueue(Event);
    const Node = Queue.Node;

    const Data = struct {
        arena: std.heap.ArenaAllocator,
        state: State = .connecting,
        allocator: std.mem.Allocator,

        free_queue: Queue = .{},
        event_queue: Queue = .{},

        pub fn pushEvent(self: *Data, event: Event) !void {
            const node = if (self.free_queue.pop()) |node|
                node
            else
                try self.arena.allocator().create(Node);
            node.* = .{
                .data = event,
            };
            self.event_queue.append(node);
        }
    };
    var global_handles: std.AutoArrayHashMap(websocket.Handle, *Data) = undefined;

    fn get(handle: websocket.Handle) ?*Data {
        return global_handles.get(handle);
    }

    handle: websocket.Handle,
    data: *Data,

    pub fn create(server: []const u8, protocols: []const []const u8) !WebSocket {
        var ptrs: [16][*]const u8 = undefined;
        var lens: [ptrs.len]usize = undefined;

        std.debug.assert(protocols.len < ptrs.len);

        for (protocols) |slice, i| {
            ptrs[i] = slice.ptr;
            lens[i] = slice.len;
        }

        const id = websocket.create(server.ptr, server.len, &ptrs, &lens, protocols.len);
        if (id == 0) {
            return error.WebsocketFailure;
        }
        errdefer websocket.destroy(id);

        var arena = std.heap.ArenaAllocator.init(gpa.allocator());
        errdefer arena.deinit();

        const data = try arena.allocator().create(Data);

        data.* = .{
            .arena = arena,
            .allocator = gpa.allocator(),
        };

        try global_handles.putNoClobber(id, data);

        return WebSocket{
            .data = data,
            .handle = id,
        };
    }

    pub fn destroy(self: *WebSocket) void {
        const data = global_handles.fetchSwapRemove(self.handle) orelse {
            std.log.err("tried to destroy unknown websocket({})", .{self.handle});
            return; // already destroyed?!
        };

        websocket.destroy(self.handle);
        self.* = undefined;

        data.value.arena.deinit();
    }

    pub fn send(self: WebSocket, binary: bool, message: []const u8) !void {
        websocket.send(self.handle, binary, message.ptr, message.len);
    }

    pub fn receive(self: WebSocket) !?Event {
        if (self.data.event_queue.popFirst()) |node| {
            defer self.data.free_queue.append(node);
            return node.data;
        } else {
            return null;
        }
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

const websocket = struct {
    const ws_logger = std.log.scoped(.websocket);
    const Handle = u32;

    extern "websocket" fn create(
        server_ptr: [*]const u8,
        server_len: usize,
        protocols_str_ptr: [*]const [*]const u8,
        protocols_len_ptr: [*]const usize,
        protocols_len: usize,
    ) Handle;
    extern "websocket" fn destroy(handle: Handle) void;
    extern "websocket" fn send(handle: Handle, binary: bool, message_ptr: [*]const u8, message_len: usize) void;

    export fn app_ws_alloc(length: u32) ?[*]u8 {
        const slice = gpa.allocator().alloc(u8, length) catch return null;
        return slice.ptr;
    }

    export fn app_ws_onmessage(handle: Handle, binary: bool, message_ptr: [*]u8, message_len: usize) void {
        const message = message_ptr[0..message_len];

        if (WebSocket.get(handle)) |ws| {
            var msg = WebSocket.Message{
                .allocator = gpa.allocator(),
                .is_binary = binary,
                .data = message,
            };

            ws.pushEvent(.{ .message = msg }) catch {
                msg.allocator.free(msg.data);
                ws_logger.info("out of memory for app_ws_onopen (2)", .{});
            };
            ws_logger.info("websocket({}) received {} of data(binary={})", .{ handle, message.len, binary });
        } else {
            gpa.allocator().free(message);
            ws_logger.err("app_ws_onmessage with invalid handle {}", .{handle});
        }
    }

    export fn app_ws_onopen(handle: Handle) void {
        if (WebSocket.get(handle)) |ws| {
            ws_logger.info("websocket({}) is now open", .{handle});
            ws.state = .open;
            ws.pushEvent(.connected) catch ws_logger.info("out of memory for app_ws_onopen", .{});
        } else {
            ws_logger.err("app_ws_onopen with invalid handle {}", .{handle});
        }
    }

    export fn app_ws_onerror(handle: Handle) void {
        if (WebSocket.get(handle)) |ws| {
            ws_logger.info("websocket({}) is now error", .{handle});
            ws.state = .@"error";
            ws.pushEvent(.@"error") catch ws_logger.info("out of memory for app_ws_onerror", .{});
        } else {
            ws_logger.err("app_ws_onerror with invalid handle {}", .{handle});
        }
    }

    export fn app_ws_onclose(handle: Handle) void {
        if (WebSocket.get(handle)) |ws| {
            ws_logger.info("websocket({}) is now closed", .{handle});
            ws.state = .closed;
            ws.pushEvent(.closed) catch ws_logger.info("out of memory for app_ws_onclose", .{});
        } else {
            ws_logger.err("app_ws_onclose with invalid handle {}", .{handle});
        }
    }

    comptime {
        if (@sizeOf(usize) != @sizeOf(u32)) {
            @compileError("no support for wasm64 yet");
        }
    }
};
