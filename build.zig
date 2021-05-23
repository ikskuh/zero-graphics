const std = @import("std");
const android_sdk = @import("ZigAndroidTemplate/Sdk.zig");

const OutputType = enum {
    exe,
    static_lib,
    dynamic_lib,
};

const RenderBackend = enum {
    desktop_sdl2,
    wasm,
    android,

    fn outputType(self: RenderBackend) OutputType {
        return switch (self) {
            .desktop_sdl2 => OutputType.exe,
            .wasm => OutputType.static_lib,
            .android => OutputType.dynamic_lib,
        };
    }
};

pub fn build(b: *std.build.Builder) !void {
    const mode = b.standardReleaseOptions();
    const backend = b.option(
        RenderBackend,
        "backend",
        "Selects the compile target for the application.",
    ) orelse .desktop_sdl2;

    const root_src = "examples/demo-application.zig";

    var zero_graphics = std.build.Pkg{
        .name = "zero-graphics",
        .path = "src/zero-graphics.zig",
    };

    if (backend == .android) {
        // TODO: Move this into a file!
        const key_store = android_sdk.KeyStore{
            .file = "zig-cache/key.store",
            .password = "123456",
            .alias = "development_key",
        };

        const sdk = try android_sdk.init(
            b,
            "ZigAndroidTemplate",
            null,
            .{},
        );

        zero_graphics.dependencies = &[_]std.build.Pkg{
            sdk.android_package,
        };

        const make_keystore = sdk.initKeystore(key_store, .{});
        b.step("init-keystore", "Initializes a fresh debug keystore.").dependOn(make_keystore);

        const app_config = android_sdk.AppConfig{
            .app_name = "zig-gles2-demo",
            .display_name = "Zig OpenGL ES 2.0 Demo",
            .package_name = "net.random_projects.zig_gles2_demo",
            .resource_directory = "zig-cache/app-resources",
        };

        const apk_file = "zig-out/demo.apk";

        const app = sdk.createApp(
            apk_file,
            root_src,
            app_config,
            mode,
            .{
                .aarch64 = true,
                .arm = true,
                .x86_64 = true,
                .x86 = false,
            },
            key_store,
        );

        for (app.libraries) |lib| {
            lib.addBuildOption(RenderBackend, "render_backend", backend);
            lib.addPackage(zero_graphics);
        }

        b.getInstallStep().dependOn(app.final_step);

        const push = sdk.installApp(apk_file);
        push.dependOn(app.final_step);

        const run = sdk.startApp(app_config);
        run.dependOn(push);

        const push_step = b.step("push", "Push the app to the default ADB target");
        push_step.dependOn(push);

        const run_step = b.step("run", "Runs the app on the default ADB target");
        run_step.dependOn(run);
    } else {
        const app = switch (backend.outputType()) {
            .exe => b.addExecutable("gles2-zig", root_src),
            .static_lib => b.addStaticLibrary("gles2-zig", root_src),
            .dynamic_lib => b.addSharedLibrary("gles2-zig", root_src, .unversioned),
        };
        app.addPackage(zero_graphics);
        app.addBuildOption(RenderBackend, "render_backend", backend);
        app.setBuildMode(mode);
        app.install();

        switch (backend) {
            .desktop_sdl2 => {
                const target = b.standardTargetOptions(.{});
                app.setTarget(target);
                app.linkLibC();
                app.linkSystemLibrary("sdl2");
            },
            .wasm => {
                app.setTarget(std.zig.CrossTarget{
                    .cpu_arch = .wasm32,
                    .os_tag = .freestanding,
                });
                app.setOutputDir("www");
                app.single_threaded = true;
            },
            .android => unreachable,
        }

        switch (backend) {
            .desktop_sdl2 => {
                const run_cmd = app.run();
                run_cmd.step.dependOn(b.getInstallStep());
                if (b.args) |args| {
                    run_cmd.addArgs(args);
                }

                const run_step = b.step("run", "Run the app");
                run_step.dependOn(&run_cmd.step);
            },
            else => {},
        }
    }
}
