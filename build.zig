const std = @import("std");
const AndroidSdk = @import("vendor/ZigAndroidTemplate/Sdk.zig");
const SdlSdk = @import("vendor/SDL.zig/Sdk.zig");

fn initApp(app: *std.build.LibExeObjStep) void {
    const cflags = [_][]const u8{
        "-std=c99",
        "-fno-sanitize=undefined",
    };

    app.addCSourceFile("src/rendering/stb_truetype.c", &cflags);
    app.addIncludeDir("vendor/stb");
}

pub fn build(b: *std.build.Builder) !void {
    const mode = b.standardReleaseOptions();

    const root_src = "examples/demo-application.zig";

    const zigimg = std.build.Pkg{
        .name = "zigimg",
        .path = .{ .path = "vendor/zigimg/zigimg.zig" },
    };

    const sdl_sdk = SdlSdk.init(b);

    if (b.option(bool, "enable-android", "Enables building the Android application") orelse false) {
        // TODO: Move this into a file!
        const key_store = AndroidSdk.KeyStore{
            .file = "zig-cache/key.store",
            .password = "123456",
            .alias = "development_key",
        };

        const sdk = AndroidSdk.init(b, null, .{});

        const make_keystore = sdk.initKeystore(key_store, .{});
        b.step("init-keystore", "Initializes a fresh debug keystore.").dependOn(make_keystore);

        const app_config = AndroidSdk.AppConfig{
            .app_name = "zerog-demo",
            .display_name = "ZeroGraphics Demo",
            .package_name = "net.random_projects.zero_graphics_demo",
            .resources = &[_]AndroidSdk.Resource{
                .{ .path = "mipmap/icon.png", .content = std.build.FileSource.relative("design/app-icon.png") },
            },
            .fullscreen = true,
        };

        const apk_file = "zig-out/demo.apk";

        const app = sdk.createApp(
            apk_file,
            root_src,
            app_config,
            mode,
            .{
                .aarch64 = true,
                .x86_64 = true,
                // 32 bit targets are currently broken
                .arm = false, // see https://github.com/ziglang/zig/issues/8885
                .x86 = false, // see https://github.com/ziglang/zig/issues/7935
            },
            key_store,
        );

        const zero_graphics = std.build.Pkg{
            .name = "zero-graphics",
            .path = .{ .path = "src/zero-graphics.zig" },
            .dependencies = &[_]std.build.Pkg{
                zigimg, app.getAndroidPackage("android"),
            },
        };
        for (app.libraries) |lib| {
            lib.addBuildOption([]const u8, "render_backend", "android");
            lib.addPackage(zero_graphics);
            initApp(lib);
        }

        b.getInstallStep().dependOn(app.final_step);

        const push = app.install();

        const run = app.run();
        run.dependOn(push);

        const push_step = b.step("install-app", "Push the app to the default ADB target");
        push_step.dependOn(push);

        const run_step = b.step("run-app", "Runs the Android app on the default ADB target");
        run_step.dependOn(run);
    }

    // Build desktop application
    {
        const app = b.addExecutable("zerog-demo", root_src);

        app.addBuildOption([]const u8, "render_backend", "desktop_sdl2");
        app.setBuildMode(mode);
        initApp(app);

        const target = b.standardTargetOptions(.{});
        app.setTarget(target);

        const zero_graphics = std.build.Pkg{
            .name = "zero-graphics",
            .path = .{ .path = "src/zero-graphics.zig" },
            .dependencies = &[_]std.build.Pkg{
                zigimg, sdl_sdk.getNativePackage("sdl2"),
            },
        };
        app.addPackage(zero_graphics);

        app.linkLibC();

        sdl_sdk.link(app, .dynamic);

        app.install();

        const run_cmd = app.run();
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const run_step = b.step("run", "Runs the desktop application");
        run_step.dependOn(&run_cmd.step);
    }

    // Build wasm application
    {
        const app = b.addSharedLibrary("zerog-demo", root_src, .unversioned);

        app.addBuildOption([]const u8, "render_backend", "wasm");
        app.setBuildMode(mode);
        initApp(app);

        const zero_graphics = std.build.Pkg{
            .name = "zero-graphics",
            .path = .{ .path = "src/zero-graphics.zig" },
            .dependencies = &[_]std.build.Pkg{
                zigimg, sdl_sdk.getNativePackage("sdl2"),
            },
        };
        app.addPackage(zero_graphics);

        // No libc on wasm!
        app.setTarget(std.zig.CrossTarget{
            .cpu_arch = .wasm32,
            .os_tag = .freestanding,
            .abi = .musl,
        });
        app.override_dest_dir = .{ .custom = "../www" };
        app.single_threaded = true;

        app.install();

        const server = b.addExecutable("http-server", "tools/http-server.zig");
        server.addPackage(std.build.Pkg{
            .name = "apple_pie",
            .path = .{ .path = "vendor/apple_pie/src/apple_pie.zig" },
        });

        const serve = server.run();
        serve.step.dependOn(&app.step);
        serve.step.dependOn(&app.install_step.?.step);

        const run_step = b.step("run-wasm", "Serves the wasm app");

        run_step.dependOn(&serve.step);
    }
}
