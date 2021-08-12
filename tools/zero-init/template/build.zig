const std = @import("std");
const Sdk = @import("vendor/zero-graphics/Sdk.zig");

pub fn build(b: *std.build.Builder) !void {
    const enable_android = b.option(bool, "enable-android", "Enables android build support. Requires the android sdk and ndk to be installed.") orelse false;

    const sdk = Sdk.init(b, enable_android);

    const mode = b.standardReleaseOptions();
    const platform = sdk.standardPlatformOptions();

    const app = sdk.createApplication("new_project", "src/main.zig");
    app.setDisplayName("New Project");
    app.setPackageName("com.example.new_project");
    app.setBuildMode(mode);

    {
        const desktop_exe = app.compileFor(platform);
        desktop_exe.install();

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
    }

    if (enable_android) {
        const android_build = app.compileFor(.android);
        android_build.install();

        b.step("init-keystore", "Initializes a fresh debug keystore.").dependOn(sdk.initializeKeystore());

        const push = android_build.android.app.install();

        const run = android_build.android.app.run();
        run.dependOn(push);

        const push_step = b.step("install-app", "Push the app to the default ADB target");
        push_step.dependOn(push);

        const run_step = b.step("run-app", "Runs the Android app on the default ADB target");
        run_step.dependOn(run);
    }
}
