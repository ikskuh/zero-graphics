const std = @import("std");
const builtin = @import("builtin");
const zero_graphics = @import("zero-graphics.zig");
const logger = std.log.scoped(.core_application);
const gl = zero_graphics.gles;

const Application = @import("application");
const CoreApplication = @This();

comptime {
    // verify the application api
    verifyApplicationType(Application);
}

allocator: std.mem.Allocator,
application: Application,
input: *zero_graphics.Input,
screen_size: zero_graphics.Size = zero_graphics.Size.empty,
resources: zero_graphics.ResourceManager,
exit_request: bool = false,

/// Returns the core application for a given application
pub fn get(app: *Application) *CoreApplication {
    return @fieldParentPtr(CoreApplication, "application", app);
}

pub fn init(app: *CoreApplication, allocator: std.mem.Allocator, input: *zero_graphics.Input) !void {
    app.* = CoreApplication{
        .allocator = allocator,
        .input = input,
        .application = undefined,
        .resources = zero_graphics.ResourceManager.init(allocator),
    };
    errdefer app.resources.deinit();

    try app.application.init(allocator, input);
}

pub fn deinit(app: *CoreApplication) void {
    app.application.deinit();
    app.resources.deinit();
    app.* = undefined;
}

pub fn exit(app: *CoreApplication) void {
    app.exit_request = true;
}

pub fn setupGraphics(app: *CoreApplication) !void {
    logger.info("OpenGL Version:  {?s}", .{std.mem.span(gl.getString(gl.VERSION))});
    logger.info("OpenGL Vendor:   {?s}", .{std.mem.span(gl.getString(gl.VENDOR))});
    logger.info("OpenGL Renderer: {?s}", .{std.mem.span(gl.getString(gl.RENDERER))});
    logger.info("OpenGL GLSL:     {?s}", .{std.mem.span(gl.getString(gl.SHADING_LANGUAGE_VERSION))});

    // If possible, install the debug callback in debug builds
    if (builtin.mode == .Debug) {
        zero_graphics.gles_utils.enableDebugOutput() catch {};
    }

    try app.resources.initializeGpuData();

    if (@hasDecl(Application, "setupGraphics")) {
        try app.setupGraphics();
    }
}

pub fn teardownGraphics(app: *CoreApplication) void {
    if (@hasDecl(Application, "teardownGraphics")) {
        app.teardownGraphics();
    }
    app.resources.destroyGpuData();
}

pub fn resize(app: *CoreApplication, width: u15, height: u15) !void {
    app.screen_size = .{ .width = width, .height = height };

    if (@hasDecl(Application, "resize")) {
        try app.resize(width, height);
    }
}

pub fn update(app: *CoreApplication) !bool {
    if (app.exit_request) {
        return false;
    }
    return try app.update();
}

pub fn render(app: *CoreApplication) !void {
    gl.viewport(0, 0, app.screen_size.width, app.screen_size.height);
    try app.render();
}

// fn init(app: *Application, allocator: std.mem.Allocator, input: zero_graphics.Input) !void
// fn setupGraphics(app: *Application) !void
// fn resize(app: *Application, width: u15, height: u15) !void
// fn update(app: *Application) !bool
// fn render(app: *Application) !void
// fn teardownGraphics(app: *Application) void
// fn deinit(app: *Application) void

fn verifyApplicationType(comptime T: type) void {
    validateSignature(T, "init", true, .{ *T, std.mem.Allocator, *zero_graphics.Input });
    validateSignature(T, "setupGraphics", false, .{*T});
    validateSignature(T, "resize", false, .{ *T, u15, u15 });
    validateSignature(T, "update", true, .{*T});
    validateSignature(T, "render", true, .{*T});
    validateSignature(T, "teardownGraphics", false, .{*T});
    validateSignature(T, "deinit", true, .{*T});
}

fn validateSignature(comptime Container: type, comptime symbol: []const u8, comptime mandatory: bool, comptime argv: anytype) void {
    comptime {
        if (@hasDecl(Container, symbol)) {
            const F = @TypeOf(@field(Container, symbol));
            const info = @typeInfo(F);
            const expected_argv: [argv.len]type = argv;

            if (info != .Fn) @compileError("Application." ++ symbol ++ "must be a function!");

            const func_info: std.builtin.TypeInfo.Fn = info.Fn;

            if (func_info.args.len != expected_argv.len)
                @compileError("Argument mismatch for Application." ++ symbol);

            for (expected_argv) |expected, i| {
                if (func_info.args[i].arg_type != expected)
                    @compileError("Type mismatch for Application." ++ symbol);
            }
        } else {
            if (mandatory) {
                @compileError("Application." ++ symbol ++ " does not exist!");
            }
        }
    }
}
