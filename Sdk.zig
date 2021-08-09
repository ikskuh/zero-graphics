const std = @import("std");

fn sdkRoot() []const u8 {
    return std.fs.path.dirname(@src().file) orelse ".";
}

const Sdk = @This();

const SdlSdk = @import("vendor/SDL.zig/Sdk.zig");
const AndroidSdk = @import("vendor/ZigAndroidTemplate/Sdk.zig");

pub const Platform = union(enum) {
    desktop: std.zig.CrossTarget,
    web,
    android,
};

const zero_graphics_package = std.build.Pkg{
    .name = "zero-graphics",
    .path = .{ .path = sdkRoot() ++ "/src/zero-graphics.zig" },
    .dependencies = &[_]std.build.Pkg{
        std.build.Pkg{
            .name = "zigimg",
            .path = .{ .path = sdkRoot() ++ "/vendor/zigimg/zigimg.zig" },
        },
    },
};

builder: *std.build.Builder,
sdl_sdk: *SdlSdk,
android_sdk: ?*AndroidSdk,
key_store: ?AndroidSdk.KeyStore,
make_keystore_step: ?*std.build.Step,

pub fn init(builder: *std.build.Builder, init_android: bool) *Sdk {
    const sdk = builder.allocator.create(Sdk) catch @panic("out of memory");
    sdk.* = Sdk{
        .builder = builder,
        .sdl_sdk = SdlSdk.init(builder),
        .android_sdk = if (init_android)
            AndroidSdk.init(builder, null, .{})
        else
            null,
        .key_store = null,
        .make_keystore_step = null,
    };

    if (sdk.android_sdk) |asdk| {
        _ = asdk;
        sdk.key_store = AndroidSdk.KeyStore{
            .file = ".build_config/android.keystore",
            .alias = "android-app",
            .password = "Ziguana",
        };

        sdk.make_keystore_step = asdk.initKeystore(sdk.key_store.?, .{});
    }

    return sdk;
}

pub fn initializeKeystore(sdk: *Sdk) *std.build.Step {
    return sdk.make_keystore_step orelse @panic("Android supported must be enabled to use this!");
}

pub fn standardPlatformOptions(sdk: *Sdk) Platform {
    const platform_tag = sdk.builder.option(std.meta.Tag(Platform), "platform", "The platform to build for") orelse .desktop;
    return switch (platform_tag) {
        .desktop => Platform{
            .desktop = sdk.builder.standardTargetOptions(.{}),
        },
        .web => .web,
        .android => .android,
    };
}

fn validateName(name: []const u8, allowed_chars: []const u8) void {
    for (name) |c| {
        if (std.mem.indexOfScalar(u8, allowed_chars, c) == null)
            std.debug.panic("The given name '{s}' contains invalid characters. Allowed characters are '{s}'", .{ name, allowed_chars });
    }
}

pub fn createApplication(sdk: *Sdk, name: []const u8, root_file: []const u8) *Application {
    return createApplicationSource(sdk, name, .{ .path = root_file });
}

pub fn createApplicationSource(sdk: *Sdk, name: []const u8, root_file: std.build.FileSource) *Application {
    validateName(name, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_");

    const app = sdk.builder.allocator.create(Application) catch @panic("out of memory");
    app.* = Application{
        .sdk = sdk,
        .name = sdk.builder.dupe(name),
        .root_file = root_file.dupe(sdk.builder),
        .packages = std.ArrayList(std.build.Pkg).init(sdk.builder.allocator),
    };
    app.addPackage(zero_graphics_package);
    return app;
}

pub const Application = struct {
    sdk: *Sdk,
    packages: std.ArrayList(std.build.Pkg),
    root_file: std.build.FileSource,
    build_mode: std.builtin.Mode = .Debug,

    name: []const u8,
    display_name: ?[]const u8 = null,
    package_name: ?[]const u8 = null,

    pub fn addPackage(app: *Application, pkg: std.build.Pkg) void {
        app.packages.append(app.sdk.builder.dupePkg(pkg)) catch @panic("out of memory!");
    }

    pub fn setBuildMode(app: *Application, mode: std.builtin.Mode) void {
        app.build_mode = mode;
    }

    /// The display name of the application. This is shown to the users.
    pub fn setDisplayName(app: *Application, name: []const u8) void {
        app.display_name = app.sdk.builder.dupe(name);
    }

    /// Java package name, usually the reverse top level domain + app name.
    /// Only lower case letters, dots and underscores are allowed.
    pub fn setPackageName(app: *Application, name: []const u8) void {
        validateName(name, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_.");
        app.package_name = app.sdk.builder.dupe(name);
    }

    fn prepareExe(exe: *std.build.LibExeObjStep, app_pkg: std.build.Pkg) void {
        exe.main_pkg_path = sdkRoot() ++ "/src";

        exe.addPackage(app_pkg);

        // TTF rendering library:
        exe.addIncludeDir(sdkRoot() ++ "/vendor/stb");
        exe.addCSourceFile(sdkRoot() ++ "/src/rendering/stb_truetype.c", &[_][]const u8{
            "-std=c99",
        });
    }

    pub fn compileFor(app: *Application, platform: Platform) *AppCompilation {
        const comp = app.sdk.builder.allocator.create(AppCompilation) catch @panic("out of memory");

        const app_pkg = app.sdk.builder.dupePkg(std.build.Pkg{
            .name = "application",
            .path = app.root_file,
            .dependencies = app.packages.items,
        });

        switch (platform) {
            .desktop => |target| {
                const exe = app.sdk.builder.addExecutable(app.name, sdkRoot() ++ "/src/main/desktop.zig");

                exe.setBuildMode(app.build_mode);
                exe.setTarget(target);

                exe.addPackage(app.sdk.sdl_sdk.getNativePackage("sdl2"));
                app.sdk.sdl_sdk.link(exe, .dynamic);

                prepareExe(exe, app_pkg);

                comp.* = AppCompilation{
                    .single_step = .{
                        .exe = exe,
                    },
                };
            },
            .web => {
                const exe = app.sdk.builder.addSharedLibrary(app.name, sdkRoot() ++ "/src/main/wasm.zig", .unversioned);
                exe.single_threaded = true;
                exe.setBuildMode(app.build_mode);
                exe.setTarget(std.zig.CrossTarget{
                    .cpu_arch = .wasm32,
                    .os_tag = .freestanding,
                    .abi = .musl,
                });

                prepareExe(exe, app_pkg);

                comp.* = AppCompilation{
                    .single_step = .{
                        .exe = exe,
                    },
                };
            },
            .android => {
                const asdk = app.sdk.android_sdk orelse @panic("Android build support is disabled!");
                const android_app = asdk.createApp(
                    app.sdk.builder.getInstallPath(.bin, app.sdk.builder.fmt("{s}.apk", .{app.name})), // apk_file: []const u8,
                    sdkRoot() ++ "/src/main/android.zig", // src_file: []const u8,
                    AndroidSdk.AppConfig{
                        .display_name = app.display_name orelse @panic("Display name is required for Android!"),
                        .app_name = app.name,
                        .package_name = app.package_name orelse @panic("Package name is required for Android"),
                        .resources = &[_]AndroidSdk.Resource{
                            .{ .path = "mipmap/icon.png", .content = .{ .path = sdkRoot() ++ "/design/app-icon.png" } },
                        },
                        .fullscreen = true,
                    }, // app_config: AppConfig,
                    app.build_mode, // mode: std.builtin.Mode,
                    AndroidSdk.AppTargetConfig{}, // targets: AppTargetConfig,
                    app.sdk.key_store.?, // key_store: KeyStore,
                );

                for (android_app.libraries) |lib| {
                    prepareExe(lib, app_pkg);

                    lib.addPackage(android_app.getAndroidPackage("android"));
                }

                comp.* = AppCompilation{
                    .android = .{
                        .app = android_app,
                        .sdk = app.sdk,
                    },
                };
            },
        }
        return comp;
    }
};

pub const AppCompilation = union(enum) {
    const Android = struct {
        app: AndroidSdk.CreateAppStep,
        sdk: *Sdk,
    };
    const Single = struct {
        exe: *std.build.LibExeObjStep,
    };

    single_step: Single,
    android: Android,

    pub fn install(comp: *AppCompilation) void {
        switch (comp.*) {
            .single_step => |step| {
                step.exe.install();
            },
            .android => |step| {
                step.sdk.builder.getInstallStep().dependOn(step.app.final_step);
            },
        }
    }

    pub fn run(comp: *AppCompilation) *std.build.RunStep {
        return switch (comp.*) {
            .single_step => |step| step.exe.run(),
            .android => @panic("Android cannot be run yet!"),
        };
    }
};
