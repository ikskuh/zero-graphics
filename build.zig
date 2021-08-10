const std = @import("std");

const Sdk = @import("Sdk.zig");

pub fn build(b: *std.build.Builder) !void {
    const enable_android = b.option(bool, "enable-android", "Enables android build support. Requires the android sdk and ndk to be installed.") orelse false;

    const sdk = Sdk.init(b, enable_android);

    const mode = b.standardReleaseOptions();
    const platform = sdk.standardPlatformOptions();

    const converter_api = b.addTranslateC(.{ .path = "tools/modelconv/api.h" });

    const converter = b.addExecutable("mconv", "tools/modelconv/main.zig");
    converter.addCSourceFile("tools/modelconv/converter.cpp", &[_][]const u8{
        "-std=c++17",
        "-Wall",
        "-Wextra",
    });
    converter.addPackage(std.build.Pkg{
        .name = "api",
        .path = .{ .generated = &converter_api.output_file },
    });
    converter.addPackage(std.build.Pkg{
        .name = "z3d",
        .path = .{ .path = "src/rendering/z3d-format.zig" },
    });
    converter.linkLibC();
    converter.linkLibCpp();
    converter.linkSystemLibrary("assimp");
    converter.install();

    const app = sdk.createApplication("demo_application", "examples/demo-application.zig");
    app.setDisplayName("ZeroGraphics Demo");
    app.setPackageName("net.random_projects.zero_graphics.demo");
    app.setBuildMode(mode);

    const exe = app.compileFor(platform);
    exe.install();

    app.compileFor(.web).install();

    if (enable_android) {
        app.compileFor(.android).install();

        b.step("init-keystore", "Initializes a fresh debug keystore.").dependOn(sdk.initializeKeystore());
    }

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // if (b.option(bool, "enable-android", "Enables building the Android application") orelse false) {
    //     // TODO: Move this into a file!
    //     const key_store = AndroidSdk.KeyStore{
    //         .file = "zig-cache/key.store",
    //         .password = "123456",
    //         .alias = "development_key",
    //     };

    //     const sdk = AndroidSdk.init(b, null, .{});

    //     const make_keystore = sdk.initKeystore(key_store, .{});
    //     b.step("init-keystore", "Initializes a fresh debug keystore.").dependOn(make_keystore);

    //     const app_config = AndroidSdk.AppConfig{
    //         .app_name = "zerog-demo",
    //         .display_name = "ZeroGraphics Demo",
    //         .package_name = "net.random_projects.zero_graphics_demo",
    //         .resources = &[_]AndroidSdk.Resource{
    //             .{ .path = "mipmap/icon.png", .content = std.build.FileSource.relative("design/app-icon.png") },
    //         },
    //         .fullscreen = true,
    //     };

    //     const apk_file = "zig-out/demo.apk";

    //     const app = sdk.createApp(
    //         apk_file,
    //         root_src,
    //         app_config,
    //         mode,
    //         .{
    //             .aarch64 = true,
    //             .x86_64 = true,
    //             // 32 bit targets are currently broken
    //             .arm = false, // see https://github.com/ziglang/zig/issues/8885
    //             .x86 = false, // see https://github.com/ziglang/zig/issues/7935
    //         },
    //         key_store,
    //     );

    //     const zero_graphics = std.build.Pkg{
    //         .name = "zero-graphics",
    //         .path = .{ .path = "src/zero-graphics.zig" },
    //         .dependencies = &[_]std.build.Pkg{
    //             zigimg, app.getAndroidPackage("android"),
    //         },
    //     };
    //     for (app.libraries) |lib| {
    //         lib.addBuildOption([]const u8, "render_backend", "android");
    //         lib.addPackage(zero_graphics);
    //         initApp(lib);
    //     }

    //     b.getInstallStep().dependOn(app.final_step);

    //     const push = app.install();

    //     const run = app.run();
    //     run.dependOn(push);

    //     const push_step = b.step("install-app", "Push the app to the default ADB target");
    //     push_step.dependOn(push);

    //     const run_step = b.step("run-app", "Runs the Android app on the default ADB target");
    //     run_step.dependOn(run);
    // }

    // // Build wasm application
    // {
    //     const app = b.addSharedLibrary("zerog-demo", root_src, .unversioned);

    //     app.addBuildOption([]const u8, "render_backend", "wasm");
    //     app.setBuildMode(mode);
    //     initApp(app);

    //     const zero_graphics = std.build.Pkg{
    //         .name = "zero-graphics",
    //         .path = .{ .path = "src/zero-graphics.zig" },
    //         .dependencies = &[_]std.build.Pkg{
    //             zigimg, sdl_sdk.getNativePackage("sdl2"),
    //         },
    //     };
    //     app.addPackage(zero_graphics);

    //     // No libc on wasm!
    //     app.setTarget(std.zig.CrossTarget{
    //         .cpu_arch = .wasm32,
    //         .os_tag = .freestanding,
    //         .abi = .musl,
    //     });
    //     app.override_dest_dir = .{ .custom = "../www" };
    //     app.single_threaded = true;

    //     app.install();

    //     const server = b.addExecutable("http-server", "tools/http-server.zig");
    //     server.addPackage(std.build.Pkg{
    //         .name = "apple_pie",
    //         .path = .{ .path = "vendor/apple_pie/src/apple_pie.zig" },
    //     });

    //     const serve = server.run();
    //     serve.step.dependOn(&app.step);
    //     serve.step.dependOn(&app.install_step.?.step);

    //     const run_step = b.step("run-wasm", "Serves the wasm app");

    //     run_step.dependOn(&serve.step);
    // }
}
