const std = @import("std");

const RenderBackend = enum {
    desktop_sdl2,
};

pub fn build(b: *std.build.Builder) void {
    const mode = b.standardReleaseOptions();
    const backend = b.option(
        RenderBackend,
        "backend",
        "Selects the compile target for the application.",
    ) orelse .desktop_sdl2;

    const exe = b.addExecutable("gles2-zig", "src/main.zig");
    exe.addBuildOption(RenderBackend, "render_backend", backend);
    exe.setBuildMode(mode);
    exe.install();

    switch (backend) {
        .desktop_sdl2 => {
            const target = b.standardTargetOptions(.{});
            exe.setTarget(target);

            exe.linkLibC();
            exe.linkSystemLibrary("sdl2");
        },
    }

    switch (backend) {
        .desktop_sdl2 => {
            const run_cmd = exe.run();
            run_cmd.step.dependOn(b.getInstallStep());
            if (b.args) |args| {
                run_cmd.addArgs(args);
            }

            const run_step = b.step("run", "Run the app");
            run_step.dependOn(&run_cmd.step);
        },
    }
}
