const std = @import("std");
const builtin = @import("builtin");
const zero_graphics = @import("zero-graphics");

const logger = std.log.scoped(.demo);
const gl = zero_graphics.gles;

const Application = @This();

allocator: *std.mem.Allocator,
input: *zero_graphics.Input,

pub fn init(app: *Application, allocator: *std.mem.Allocator, input: *zero_graphics.Input) !void {
    app.* = Application{
        .allocator = allocator,
        .input = input,
    };

    // initialize your application logic here!
}

pub fn deinit(app: *Application) void {
    // shut down your application here
    app.* = undefined;
}

pub fn setupGraphics(app: *Application) !void {
    logger.info("OpenGL Version:       {s}", .{std.mem.span(gl.getString(gl.VERSION))});
    logger.info("OpenGL Vendor:        {s}", .{std.mem.span(gl.getString(gl.VENDOR))});
    logger.info("OpenGL Renderer:      {s}", .{std.mem.span(gl.getString(gl.RENDERER))});
    logger.info("OpenGL GLSL:          {s}", .{std.mem.span(gl.getString(gl.SHADING_LANGUAGE_VERSION))});

    // If possible, install the debug callback in debug builds
    if (builtin.mode == .Debug) {
        zero_graphics.gles_utils.enableDebugOutput() catch {};
    }

    // initialize your graphics objects here!
    _ = app;
}

pub fn teardownGraphics(app: *Application) void {
    // destroy your graphics objects here!
    _ = app;
}

pub fn resize(app: *Application, width: u15, height: u15) !void {
    // react to screen resizes here!
    _ = app;
    _ = width;
    _ = height;
}

pub fn update(app: *Application) !bool {
    // process input events here:
    while (app.input.pollEvent()) |event| {
        switch (event) {
            .quit => return false,
            .pointer_motion => {},
            .pointer_press => {},
            .pointer_release => {},
            .text_input => {},
            .key_down => {},
            .key_up => {},
        }
    }

    return true;
}

pub fn render(app: *Application) !void {
    gl.clearColor(0.3, 0.3, 0.3, 1.0);
    gl.clearDepthf(1.0);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

    // Render your application here
    _ = app;
}
