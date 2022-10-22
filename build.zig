const std = @import("std");

const Sdk = @import("Sdk.zig");
const Assimp = @import("vendor/zig-assimp/Sdk.zig");

pub fn build(b: *std.build.Builder) !void {
    const enable_android = b.option(bool, "enable-android", "Enables android build support. Requires the android sdk and ndk to be installed.") orelse false;

    const app_only_step = b.step("app", "Builds only the desktop application");

    const sdk = Sdk.init(b, enable_android);
    const assimp = Assimp.init(b);

    const mode = b.standardReleaseOptions();
    const platform = sdk.standardPlatformOptions();

    {
        const zero_init = b.addExecutable("zero-init", "tools/zero-init/main.zig");
        zero_init.addPackage(std.build.Pkg{
            .name = "args",
            .source = .{ .path = "vendor/args/args.zig" },
        });
        zero_init.install();
    }

    // compile the zero-init example so can be sure that it actually compiles!
    {
        const app = sdk.createApplication("zero_init_app", "tools/zero-init/template/src/main.zig");
        app.setDisplayName("ZeroGraphics Init App");
        app.setPackageName("net.random_projects.zero_graphics.init_app");
        app.setBuildMode(mode);

        b.getInstallStep().dependOn(app.compileFor(platform).getStep());
        b.getInstallStep().dependOn(app.compileFor(.web).getStep());
        if (enable_android) {
            b.getInstallStep().dependOn(app.compileFor(.android).getStep());
        }
    }

    {
        const converter_api = b.addTranslateC(.{ .path = "tools/zero-convert/api.h" });

        const converter = b.addExecutable("zero-convert", "tools/zero-convert/main.zig");
        converter.addCSourceFile("tools/zero-convert/converter.cpp", &[_][]const u8{
            "-std=c++17",
            "-Wall",
            "-Wextra",
        });
        converter.addPackage(std.build.Pkg{
            .name = "api",
            .source = .{ .generated = &converter_api.output_file },
        });
        converter.addPackage(std.build.Pkg{
            .name = "z3d",
            .source = .{ .path = "src/rendering/z3d-format.zig" },
        });
        converter.addPackage(std.build.Pkg{
            .name = "args",
            .source = .{ .path = "vendor/args/args.zig" },
        });
        converter.linkLibC();
        converter.linkLibCpp();
        assimp.addTo(converter, .static, Assimp.FormatSet.default);
        converter.install();
    }

    const app = sdk.createApplication("demo_application", "examples/demo-application.zig");
    app.setDisplayName("ZeroGraphics Demo");
    app.setPackageName("net.random_projects.zero_graphics.demo");
    app.setBuildMode(mode);

    app.addPackage(std.build.Pkg{
        .name = "zlm",
        .source = .{ .path = "vendor/zlm/zlm.zig" },
    });

    {
        const desktop_exe = app.compileFor(platform);
        desktop_exe.install();

        app_only_step.dependOn(&desktop_exe.data.desktop.install_step.?.step);

        const run_cmd = desktop_exe.run();
        run_cmd.step.dependOn(b.getInstallStep());
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const run_step = b.step("run", "Run the app");
        run_step.dependOn(&run_cmd.step);
    }

    // Build wasm application
    {
        const wasm_build = app.compileFor(.web);
        wasm_build.install();

        const serve = wasm_build.run();

        const build_step = b.step("build-wasm", "Builds the wasm app and installs it.");
        build_step.dependOn(wasm_build.install_step.?);

        const run_step = b.step("run-wasm", "Serves the wasm app");
        run_step.dependOn(&serve.step);
    }

    if (enable_android) {
        const android_build = app.compileFor(.android);
        android_build.install();

        b.step("init-keystore", "Initializes a fresh debug keystore.").dependOn(sdk.initializeKeystore());

        const push = android_build.data.android.install();

        const run = android_build.data.android.run();
        run.dependOn(push);

        const push_step = b.step("install-app", "Push the app to the default ADB target");
        push_step.dependOn(push);

        const run_step = b.step("run-app", "Runs the Android app on the default ADB target");
        run_step.dependOn(run);
    }
}
