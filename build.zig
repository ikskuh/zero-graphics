const std = @import("std");
const android_app = @import("ZigAndroidTemplate/android-app.zig");

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

pub fn build(b: *std.build.Builder) void {
    const mode = b.standardReleaseOptions();
    const backend = b.option(
        RenderBackend,
        "backend",
        "Selects the compile target for the application.",
    ) orelse .desktop_sdl2;

    if (backend == .android) {
        const android_config = android_app.Config{
            .sdk_root = "/home/felix/projects/uncategorized/android-hass/android-sdk",
            .ndk_root = "/home/felix/projects/uncategorized/android-hass/android-sdk/ndk/21.1.6352462",
            .build_tools = "/home/felix/projects/uncategorized/android-hass/android-sdk/build-tools/28.0.3",
            .key_store = android_app.KeyStore{
                .file = "zig-cache/key.store",
                .password = "123456",
                .alias = "development_key",
            },
        };

        const make_keystore = android_app.initKeystore(b, android_config, .{});
        b.step("keystore", "Initializes a fresh keystore.").dependOn(make_keystore);

        const app_config = android_app.AppConfig{
            .app_name = "zig-gles2-demo",
            .display_name = "Zig OpenGL ES 2.0 Demo",
            .package_name = "net.random_projects.zig-gles2-demo",
            .resource_directory = "zig-cache/app-resources",
        };

        const app = android_app.createApp(
            b,
            android_config,
            "zig-out/demo.apk",
            "src/main.zig",
            app_config,
            mode,
            .{},
        );

        for (app.libraries) |lib| {
            lib.addBuildOption(RenderBackend, "render_backend", backend);
        }

        b.getInstallStep().dependOn(app.final_step);
    } else {
        const app = switch (backend.outputType()) {
            .exe => b.addExecutable("gles2-zig", "src/main.zig"),
            .static_lib => b.addStaticLibrary("gles2-zig", "src/main.zig"),
            .dynamic_lib => b.addSharedLibrary("gles2-zig", "src/main.zig", .unversioned),
        };
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
