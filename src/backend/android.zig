const std = @import("std");
const wasm = std.log.scoped(.sdl);
const root = @import("root");
const gles = @import("../gl_es_2v0.zig");
const logger = std.log.scoped(.sdl);
const zerog = @import("../zero-graphics.zig");

const android = @import("android");

const EGLContext = android.egl.EGLContext;
const JNI = android.JNI;

pub const log = android.log;
pub const panic = android.panic;

pub fn loadOpenGlFunction(ctx: void, function: [:0]const u8) ?*const c_void {
    // We can "safely" convert the function name here as eglGetProcAddress is documented as `const`
    return android.egl.c.eglGetProcAddress(function.ptr);
}

pub const AndroidApp = struct {
    const Self = @This();

    allocator: *std.mem.Allocator,
    activity: *android.ANativeActivity,

    thread: ?*std.Thread = null,
    running: bool = true,

    egl_lock: std.Thread.Mutex = std.Thread.Mutex{},
    egl: ?EGLContext = null,
    egl_init: bool = true,

    input_lock: std.Thread.Mutex = std.Thread.Mutex{},
    input: ?*android.AInputQueue = null,

    config: ?*android.AConfiguration = null,

    screen_width: f32 = undefined,
    screen_height: f32 = undefined,

    app_ready: bool = false,
    application: root.Application,

    zero_input: zerog.Input,

    /// This is the entry point which initializes a application
    /// that has stored its previous state.
    /// `stored_state` is that state, the memory is only valid for this function.
    pub fn initRestore(allocator: *std.mem.Allocator, activity: *android.ANativeActivity, stored_state: []const u8) !Self {
        return Self{
            .allocator = allocator,
            .activity = activity,
            .application = undefined,
            .zero_input = zerog.Input.init(std.heap.c_allocator),
        };
    }

    /// This is the entry point which initializes a application
    /// that has no previous state.
    pub fn initFresh(allocator: *std.mem.Allocator, activity: *android.ANativeActivity) !Self {
        return Self{
            .allocator = allocator,
            .activity = activity,
            .application = undefined,
            .zero_input = zerog.Input.init(std.heap.c_allocator),
        };
    }

    /// This function is called when the application is successfully initialized.
    /// It should create a background thread that processes the events and runs until
    /// the application gets destroyed.
    pub fn start(self: *Self) !void {
        // This code somehow crashes yet. Needs more investigations
        // {
        //     var jni = JNI.init(self.activity);
        //     defer jni.deinit();

        //     // Must be called from main thread…
        //     _ = jni.AndroidMakeFullscreen();
        // }
        self.thread = try std.Thread.spawn(mainLoop, self);
    }

    /// Uninitialize the application.
    /// Don't forget to stop your background thread here!
    pub fn deinit(self: *Self) void {
        @atomicStore(bool, &self.running, false, .SeqCst);
        if (self.thread) |thread| {
            thread.wait();
            self.thread = null;
        }
        if (self.config) |config| {
            android.AConfiguration_delete(config);
        }
        self.zero_input.deinit();
        self.* = undefined;
    }

    pub fn onNativeWindowCreated(self: *Self, window: *android.ANativeWindow) void {
        var held = self.egl_lock.acquire();
        defer held.release();

        if (self.egl) |*old| {
            old.deinit();
        }

        self.screen_width = @intToFloat(f32, android.ANativeWindow_getWidth(window));
        self.screen_height = @intToFloat(f32, android.ANativeWindow_getHeight(window));

        self.egl = EGLContext.init(window, .gles2) catch |err| blk: {
            logger.err("Failed to initialize EGL for window: {}\n", .{err});
            break :blk null;
        };
        self.egl_init = true;
    }

    pub fn onNativeWindowDestroyed(self: *Self, window: *android.ANativeWindow) void {
        var held = self.egl_lock.acquire();
        defer held.release();

        if (self.egl) |*old| {
            old.deinit();
        }
        self.egl = null;
    }

    pub fn onInputQueueCreated(self: *Self, input: *android.AInputQueue) void {
        var held = self.input_lock.acquire();
        defer held.release();

        self.input = input;
    }

    pub fn onInputQueueDestroyed(self: *Self, input: *android.AInputQueue) void {
        var held = self.input_lock.acquire();
        defer held.release();

        self.input = null;
    }

    fn printConfig(config: *android.AConfiguration) void {
        var lang: [2]u8 = undefined;
        var country: [2]u8 = undefined;

        android.AConfiguration_getLanguage(config, &lang);
        android.AConfiguration_getCountry(config, &country);

        logger.debug(
            \\MCC:         {}
            \\MNC:         {}
            \\Language:    {s}
            \\Country:     {s}
            \\Orientation: {}
            \\Touchscreen: {}
            \\Density:     {}
            \\Keyboard:    {}
            \\Navigation:  {}
            \\KeysHidden:  {}
            \\NavHidden:   {}
            \\SdkVersion:  {}
            \\ScreenSize:  {}
            \\ScreenLong:  {}
            \\UiModeType:  {}
            \\UiModeNight: {}
            \\
        , .{
            android.AConfiguration_getMcc(config),
            android.AConfiguration_getMnc(config),
            &lang,
            &country,
            android.AConfiguration_getOrientation(config),
            android.AConfiguration_getTouchscreen(config),
            android.AConfiguration_getDensity(config),
            android.AConfiguration_getKeyboard(config),
            android.AConfiguration_getNavigation(config),
            android.AConfiguration_getKeysHidden(config),
            android.AConfiguration_getNavHidden(config),
            android.AConfiguration_getSdkVersion(config),
            android.AConfiguration_getScreenSize(config),
            android.AConfiguration_getScreenLong(config),
            android.AConfiguration_getUiModeType(config),
            android.AConfiguration_getUiModeNight(config),
        });
    }

    fn processKeyEvent(self: *Self, event: *android.AInputEvent) !bool {
        const event_type = @intToEnum(android.AKeyEventActionType, android.AKeyEvent_getAction(event));
        std.log.scoped(.input).debug(
            \\Key Press Event: {}
            \\Flags:       {}
            \\KeyCode:     {}
            \\ScanCode:    {}
            \\MetaState:   {}
            \\RepeatCount: {}
            \\DownTime:    {}
            \\EventTime:   {}
            \\
        , .{
            event_type,
            android.AKeyEvent_getFlags(event),
            android.AKeyEvent_getKeyCode(event),
            android.AKeyEvent_getScanCode(event),
            android.AKeyEvent_getMetaState(event),
            android.AKeyEvent_getRepeatCount(event),
            android.AKeyEvent_getDownTime(event),
            android.AKeyEvent_getEventTime(event),
        });

        if (event_type == .AKEY_EVENT_ACTION_DOWN) {
            var jni = JNI.init(self.activity);
            defer jni.deinit();

            var codepoint = jni.AndroidGetUnicodeChar(
                android.AKeyEvent_getKeyCode(event),
                android.AKeyEvent_getMetaState(event),
            );
            var buf: [8]u8 = undefined;

            var len = std.unicode.utf8Encode(codepoint, &buf) catch 0;
            var key_text = buf[0..len];

            std.log.scoped(.input).info("Pressed key: '{s}' U+{X}", .{ key_text, codepoint });

            try self.zero_input.pushEvent(.{
                .text_input = .{
                    .text = key_text,
                    .modifiers = .{
                        // TODO: Implement this properly
                        .alt = false,
                        .ctrl = false,
                        .shift = false,
                        .super = false,
                    },
                },
            });
        }

        return false;
    }

    fn processMotionEvent(self: *Self, event: *android.AInputEvent) !bool {
        const event_type = @intToEnum(android.AMotionEventActionType, android.AMotionEvent_getAction(event));

        {
            var jni = JNI.init(self.activity);
            defer jni.deinit();

            // Show/Hide keyboard
            // _ = jni.AndroidDisplayKeyboard(true);

            // this allows you to send the app in the background
            // const success = jni.AndroidSendToBack(true);
            // std.logger.debug(.app, "SendToBack() = {}\n", .{success});

            // This is a demo on how to request permissions:
            // if (event_type == .AMOTION_EVENT_ACTION_UP) {
            //     if (!JNI.AndroidHasPermissions(self.activity, "android.permission.RECORD_AUDIO")) {
            //         JNI.AndroidRequestAppPermissions(self.activity, "android.permission.RECORD_AUDIO");
            //     }
            // }
        }

        std.log.scoped(.input).debug(
            \\Motion Event {}
            \\Flags:        {}
            \\MetaState:    {}
            \\ButtonState:  {}
            \\EdgeFlags:    {}
            \\DownTime:     {}
            \\EventTime:    {}
            \\XOffset:      {}
            \\YOffset:      {}
            \\XPrecision:   {}
            \\YPrecision:   {}
            \\PointerCount: {}
            \\
        , .{
            event_type,
            android.AMotionEvent_getFlags(event),
            android.AMotionEvent_getMetaState(event),
            android.AMotionEvent_getButtonState(event),
            android.AMotionEvent_getEdgeFlags(event),
            android.AMotionEvent_getDownTime(event),
            android.AMotionEvent_getEventTime(event),
            android.AMotionEvent_getXOffset(event),
            android.AMotionEvent_getYOffset(event),
            android.AMotionEvent_getXPrecision(event),
            android.AMotionEvent_getYPrecision(event),
            android.AMotionEvent_getPointerCount(event),
        });

        var i: usize = 0;
        var cnt = android.AMotionEvent_getPointerCount(event);
        while (i < cnt) : (i += 1) {
            std.log.scoped(.input).debug(
                \\Pointer {}:
                \\  PointerId:   {}
                \\  ToolType:    {}
                \\  RawX:        {d}
                \\  RawY:        {d}
                \\  X:           {d}
                \\  Y:           {d}
                \\  Pressure:    {}
                \\  Size:        {}
                \\  TouchMajor:  {}
                \\  TouchMinor:  {}
                \\  ToolMajor:   {}
                \\  ToolMinor:   {}
                \\  Orientation: {}
                \\
            , .{
                i,
                android.AMotionEvent_getPointerId(event, i),
                android.AMotionEvent_getToolType(event, i),
                android.AMotionEvent_getRawX(event, i),
                android.AMotionEvent_getRawY(event, i),
                android.AMotionEvent_getX(event, i),
                android.AMotionEvent_getY(event, i),
                android.AMotionEvent_getPressure(event, i),
                android.AMotionEvent_getSize(event, i),
                android.AMotionEvent_getTouchMajor(event, i),
                android.AMotionEvent_getTouchMinor(event, i),
                android.AMotionEvent_getToolMajor(event, i),
                android.AMotionEvent_getToolMinor(event, i),
                android.AMotionEvent_getOrientation(event, i),
            });
        }

        return false;
    }

    fn mainLoop(self: *Self) !void {
        logger.notice("mainLoop() started\n", .{});
        defer logger.notice("mainLoop() finished\n", .{});

        self.config = blk: {
            var cfg = android.AConfiguration_new() orelse return error.OutOfMemory;
            android.AConfiguration_fromAssetManager(cfg, self.activity.assetManager);
            break :blk cfg;
        };

        if (self.config) |cfg| {
            printConfig(cfg);
        }

        while (@atomicLoad(bool, &self.running, .SeqCst)) {

            // Input process
            {
                // we lock the handle of our input so we don't have a race condition
                var held = self.input_lock.acquire();
                defer held.release();
                if (self.input) |input| {
                    var event: ?*android.AInputEvent = undefined;
                    while (android.AInputQueue_getEvent(input, &event) >= 0) {
                        std.debug.assert(event != null);
                        if (android.AInputQueue_preDispatchEvent(input, event) != 0) {
                            continue;
                        }

                        const event_type = @intToEnum(android.AInputEventType, android.AInputEvent_getType(event));
                        const handled = switch (event_type) {
                            .AINPUT_EVENT_TYPE_KEY => try self.processKeyEvent(event.?),
                            .AINPUT_EVENT_TYPE_MOTION => try self.processMotionEvent(event.?),
                            else => blk: {
                                std.log.scoped(.input).debug("Unhandled input event type ({})\n", .{event_type});
                                break :blk false;
                            },
                        };

                        // if (app.onInputEvent != NULL)
                        //     handled = app.onInputEvent(app, event);
                        android.AInputQueue_finishEvent(input, event, if (handled) @as(c_int, 1) else @as(c_int, 0));
                    }
                }
            }

            // Render process
            {
                // same for the EGL context
                var held = self.egl_lock.acquire();
                defer held.release();
                if (self.egl) |egl| {
                    try egl.makeCurrent();
                    const screen_width = @floatToInt(u15, self.screen_width);
                    const screen_height = @floatToInt(u15, self.screen_height);

                    if (self.egl_init) {
                        // ready
                        self.egl_init = false;

                        try self.application.init(std.heap.c_allocator, &self.zero_input);

                        self.app_ready = true;
                    }

                    if (self.app_ready) {
                        try self.application.resize(screen_width, screen_height);
                        const res = try self.application.update();
                        if (!res)
                            std.os.exit(0);
                    } else {
                        android.egl.c.glClearColor(1, 0, 1, 1);
                        android.egl.c.glClear(android.egl.c.GL_COLOR_BUFFER_BIT);
                    }

                    try egl.swapBuffers();
                }
            }
            std.time.sleep(10 * std.time.ns_per_ms);
        }
    }
};
