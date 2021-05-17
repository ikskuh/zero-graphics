const std = @import("std");

const OutputType = enum {
    exe,
    static_lib,
    dynamic_lib,
};

const RenderBackend = enum {
    desktop_sdl2,
    wasm,

    fn outputType(self: RenderBackend) OutputType {
        return switch (self) {
            .desktop_sdl2 => OutputType.exe,
            .wasm => OutputType.static_lib,
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
        },
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
