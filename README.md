# Zero Graphics

A very minimal OpenGL ES 2.0 library for Zig. Opens you a window and let's you draw things.
Comes with a pixel-perfect 2D renderer and maybe some day even with a bit of a 3D api.

![Logo](design/logo.png)

## Project status
Very *work in progress*. Right now it's more a proof of concept than everything else

![Preview screenshot in FireFox](https://mq32.de/public/7207fdc86224d69a7af0e8289c6b7a687c757cf8.png)

## Project Goals

### Basic Framework
- [ ] Support the following platforms
  - [x] Wasm
  - [x] Linux Desktop
  - [ ] Windows Desktop (not tested, but should work via SDL2)
  - [x] Android
- [x] Create an OpenGL ES 2.0 context
- [x] Provide input events
  - [x] Single pointer motion (finger or mouse)
  - [x] Single click event (finger, mouse)
  - [ ] Text input for keyboard (utf-8 encoded)
- [x] Provide window events
  - [x] Resize
  - [x] Close
- [x] Provide access to the underlying backend
- [ ] Allow creation of single-file applications
  - [ ] Single executable for easy distribution
  - [ ] Embedded resources

### 2D Rendering library
- [ ] Pixel perfect drawing of
  - [x] Lines
  - [x] Rectangles
  - [ ] Images
    - [x] Basic "copy full texture to rectangle"
    - [ ] Copy portion of texture ("atlas rendering")
- [x] TTF font rendering via [`stb_ttf`](https://github.com/nothings/stb)
- [x] Image loading via [`zigimg`](https://github.com/zigimg/zigimg)
- [ ] Stack based/nested scissoring

## Features

- Support for desktop linux
- Mobile linux (PinePhone) supported as well
- Browser support via Wasm
- *coming soon:* Android support
- Pixel perfect 2D rendering


## Dependencies

### Desktop
- SDL2

### Web
- [js glue code](www/binding.js)

### Android
- Android SDK
- Android NDK
- Android Build Tools
- OpenJDK
- some other tools

## Building / Running

### Desktop PC

Requires `SDL2` to be installed.

```sh
zig build run
```

A window should open with the application in fullscreen.

### Web/Wasm version

Includes a teeny tiny web server for debugging.

```sh
zig build install run-wasm
```

Now visit http://127.0.0.1:8000/index.htm to see the demo.

### Android

Connect your phone first and install both a JDK as well as the Android SDK with NDK included. The ZeroGraphics build system will tell you if
it couldn't auto-detect the SDK paths.

```sh
zig build -Denable-android run-app
```

The app should now be installed and started on your phone.

## Documentation

### Getting started

To create a new project, copy this application skeleton:
```zig
const std = @import("std");
const zero_graphics_builder = @import("zero-graphics");

const zero_graphics = zero_graphics_builder.Api(zero_graphics_builder.Backend.desktop_sdl2);

pub usingnamespace zero_graphics.entry_point;

/// This implements your application with all state
pub const Application = struct {
    allocator: *std.mem.Allocator,
    input: *zero_graphics.Input,

    pub fn init(app: *Application, allocator: *std.mem.Allocator, input: *zero_graphics.Input) !void {
        // Initialize the app and all non-gpu logic here
        app.* = Application{
            .allocator = allocator,
            .input = input,
        };
    }

    pub fn deinit(app: *Application) void {
        // destroy application data here
        app.* = undefined;
    }

    pub fn setupGraphics(app: *Application) !void {
        // initialize all OpenGL objects here
    }

    pub fn teardownGraphics(app: *Application) void {
        // destroy all OpenGL objects here
    }

    pub fn update(app: *Application) !bool {
        while (app.input.pollEvent()) |event| {
            switch (event) {
                .quit => return false,
                else => std.log.info("unhandled input event: {}", .{event}),
            }
        }

        // return false to exit the application
        return true;
    }

    pub fn resize(app: *Application, width: u15, height: u15) !void {
        // handle application resize logic here
    }

    pub fn render(app: *Application) !void {
        // OpenGL is already loaded, so we can just use it :)
        // render will never be called before `setupGraphics` is called and never
        // after `teardownGraphics` was called.
        zero_graphics.gles.clearColor(0.3, 0.3, 0.3, 1.0);
        zero_graphics.gles.clear(gles.COLOR_BUFFER_BIT);
    }
};
```

The functions are roughly called in this order:

![Application workflow](documentation/app_flow.svg)

The separation between *application init* and *graphics init* is relevant for Android apps which will destroy their window when you send it into the background and will recreate it when it is selected again. This means that all GPU content will be lost then and must be restored.

Your application state will not be destroyed, so the rendering can render the same data as before.

### Configuration

For the desktop variant, the following environment variables are available for configuration:
- `DUNSTBLICK_DPI` might be used to set a fallback display density when the display one could not be determined
- `DUNSTBLICK_FULLSCREEN` might be used to enforce fullscreen or window mode. Use `yes` or `no`