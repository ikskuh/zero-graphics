//! This file must export the following functions:
//! - `pub fn init(app: *Application, allocator: std.mem.Allocator) !void`
//! - `pub fn update(app: *Application) !bool`
//! - `pub fn render(app: *Application) !void`
//! - `pub fn deinit(app: *Application) void`
//!
//! This file *can* export the following functions:
//! - `pub fn setupGraphics(app: *Application) !void`
//! - `pub fn resize(app: *Application, width: u15, height: u15) !void`
//! - `pub fn teardownGraphics(app: *Application) void`
//!

const std = @import("std");
const builtin = @import("builtin");
const zero_graphics = @import("zero-graphics");

const logger = std.log.scoped(.demo);
const gl = zero_graphics.gles;

const core = zero_graphics.CoreApplication.get;

const Application = @This();

pub fn init(app: *Application) !void {
    app.* = Application{};
    // TODO: initialize your application logic here!
}

pub fn deinit(app: *Application) void {
    // TODO: shut down your application here
    app.* = undefined;
}

pub fn update(app: *Application) !bool {

    // TODO: process input events here:
    while (core().input.fetch()) |event| {
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

    _ = app;

    return true;
}

pub fn render(app: *Application) !void {
    gl.clearColor(0.3, 0.3, 0.3, 1.0);
    gl.clearDepthf(1.0);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

    // Render your application here
    _ = app;
}
