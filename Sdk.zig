const std = @import("std");

fn sdkRoot() []const u8 {
    return std.fs.path.dirname(@src().file) orelse ".";
}

const Sdk = @This();

const SdlSdk = @import("vendor/SDL.zig/Sdk.zig");
const AndroidSdk = @import("vendor/ZigAndroidTemplate/Sdk.zig");
const TemplateStep = @import("vendor/ztt/src/TemplateStep.zig");

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

const web_folder = std.build.InstallDir{ .custom = "www" };

builder: *std.build.Builder,
sdl_sdk: *SdlSdk,
android_sdk: ?*AndroidSdk,
key_store: ?AndroidSdk.KeyStore,
make_keystore_step: ?*std.build.Step,

install_web_sources: []*std.build.InstallFileStep,

render_main_page_tool: *std.build.LibExeObjStep,

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
        .install_web_sources = builder.allocator.dupe(*std.build.InstallFileStep, &[_]*std.build.InstallFileStep{
            builder.addInstallFileWithDir(.{ .path = sdkRoot() ++ "/www/zero-graphics.js" }, web_folder, "zero-graphics.js"),
        }) catch @panic("out of memory"),
        .render_main_page_tool = builder.addExecutable("render-html-page", sdkRoot() ++ "/tools/render-ztt-page.zig"),
    };

    sdk.render_main_page_tool.addPackage(.{
        .name = "html",
        .path = TemplateStep.transform(builder, sdkRoot() ++ "/www/application.ztt"),
    });

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
    const create_meta_step = CreateAppMetaStep.create(sdk, app);
    app.* = Application{
        .sdk = sdk,
        .name = sdk.builder.dupe(name),
        .root_file = root_file.dupe(sdk.builder),
        .packages = std.ArrayList(std.build.Pkg).init(sdk.builder.allocator),
        .meta_pkg = std.build.Pkg{
            .name = "application-meta",
            .path = std.build.FileSource{ .generated = &create_meta_step.outfile },
        },
    };
    app.addPackage(zero_graphics_package);

    return app;
}

pub const Size = struct {
    width: u15,
    height: u15,
};

pub const InitialResolution = union(enum) {
    fullscreen,
    windowed: Size,
};

pub const Application = struct {
    sdk: *Sdk,
    packages: std.ArrayList(std.build.Pkg),
    root_file: std.build.FileSource,
    build_mode: std.builtin.Mode = .Debug,
    meta_pkg: std.build.Pkg,

    name: []const u8,
    display_name: ?[]const u8 = null,
    package_name: ?[]const u8 = null,
    resolution: InitialResolution = .{ .windowed = Size{ .width = 1280, .height = 720 } },

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

    /// Sets the initial preferred resolution for the application.
    /// This isn't a hard constraint, but zero-graphics tries to satisfy this if possible.
    /// Some backends can only provide fullscreen applications though.
    pub fn setInitialResolution(app: *Application, resolution: InitialResolution) void {
        app.resolution = resolution;
    }

    fn prepareExe(app: *Application, exe: *std.build.LibExeObjStep, app_pkg: std.build.Pkg) void {
        exe.main_pkg_path = sdkRoot() ++ "/src";

        exe.addPackage(app_pkg);
        exe.addPackage(app.meta_pkg);

        // TTF rendering library:
        exe.addIncludeDir(sdkRoot() ++ "/vendor/stb");
        exe.addCSourceFile(sdkRoot() ++ "/src/rendering/stb_truetype.c", &[_][]const u8{
            "-std=c99",
        });
    }

    pub fn compileFor(app: *Application, platform: Platform) *AppCompilation {
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

                app.prepareExe(exe, app_pkg);

                return app.createCompilation(.{
                    .desktop = exe,
                });
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

                app.prepareExe(exe, app_pkg);

                return app.createCompilation(.{
                    .web = exe,
                });
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
                    app.prepareExe(lib, app_pkg);

                    lib.addPackage(android_app.getAndroidPackage("android"));
                }

                return app.createCompilation(.{
                    .android = android_app,
                });
            },
        }
    }

    fn createCompilation(app: *Application, data: AppCompilation.Data) *AppCompilation {
        const comp = app.sdk.builder.allocator.create(AppCompilation) catch @panic("out of memory");
        comp.* = AppCompilation{
            .sdk = app.sdk,
            .app = app,
            .data = data,
        };
        return comp;
    }
};

pub const AppCompilation = struct {
    const Data = union(enum) {
        desktop: *std.build.LibExeObjStep,
        web: *std.build.LibExeObjStep,
        android: AndroidSdk.CreateAppStep,
    };

    sdk: *Sdk,
    app: *Application,
    data: Data,

    pub fn getStep(comp: *AppCompilation) *std.build.Step {
        return switch (comp.data) {
            .desktop => |step| &step.step,
            .web => |step| &step.step,
            .android => |android| android.final_step,
        };
    }

    pub fn install(comp: *AppCompilation) void {
        switch (comp.data) {
            .desktop => |step| step.install(),
            .web => |step| {
                step.install();

                const install_step = step.install_step.?;
                install_step.dest_dir = web_folder;

                for (comp.sdk.install_web_sources) |installer| {
                    install_step.step.dependOn(&installer.step);
                }

                const file_name = comp.sdk.builder.fmt("{s}.htm", .{step.name});

                const app_html_page = CreateApplicationHtmlPageStep.create(
                    comp.sdk,
                    comp.app.name,
                    comp.app.display_name orelse "Untitled Application",
                );

                const install_html_page = comp.sdk.builder.addInstallFileWithDir(.{ .generated = &app_html_page.outfile }, web_folder, file_name);
                install_html_page.step.dependOn(&app_html_page.step);

                install_step.step.dependOn(&install_html_page.step);
            },
            .android => |step| {
                comp.sdk.builder.getInstallStep().dependOn(step.final_step);
            },
        }
    }

    pub fn run(comp: *AppCompilation) *std.build.RunStep {
        return switch (comp.data) {
            .desktop => |step| step.run(),
            .web => @panic("Web cannot be run yet!"),
            .android => @panic("Android cannot be run yet!"),
        };
    }
};

const CreateAppMetaStep = struct {
    step: std.build.Step,
    app: *Application,

    outfile: std.build.GeneratedFile,

    pub fn create(sdk: *Sdk, app: *Application) *CreateAppMetaStep {
        const ms = sdk.builder.allocator.create(CreateAppMetaStep) catch @panic("out of memory");
        ms.* = CreateAppMetaStep{
            .step = std.build.Step.init(.custom, "Create application meta data", sdk.builder.allocator, make),
            .app = app,
            .outfile = std.build.GeneratedFile{ .step = &ms.step },
        };
        return ms;
    }

    fn make(step: *std.build.Step) !void {
        const self = @fieldParentPtr(CreateAppMetaStep, "step", step);

        var cache = CacheBuilder.init(self.app.sdk.builder, "zero-graphics");

        var file_data = std.ArrayList(u8).init(self.app.sdk.builder.allocator);
        defer file_data.deinit();
        {
            const writer = file_data.writer();

            try writer.print("pub const name = \"{}\";\n", .{
                std.zig.fmtEscapes(self.app.name),
            });
            try writer.print("pub const display_name = \"{}\";\n", .{
                std.zig.fmtEscapes(self.app.display_name orelse self.app.name),
            });
            try writer.print("pub const package_name = \"{}\";\n", .{
                std.zig.fmtEscapes(self.app.package_name orelse self.app.name),
            });
            if (self.app.resolution == .windowed) {
                try writer.print("pub const initial_resolution = .{{ .width = {}, .height = {} }};\n", .{
                    self.app.resolution.windowed.width,
                    self.app.resolution.windowed.height,
                });
            }
        }

        cache.addBytes(file_data.items);

        self.outfile.path = try cache.createSingleFile("app-meta.zig", file_data.items);
    }
};

const CreateApplicationHtmlPageStep = struct {
    step: std.build.Step,

    sdk: *Sdk,
    app_name: []const u8,
    display_name: []const u8,

    outfile: std.build.GeneratedFile,

    pub fn create(sdk: *Sdk, app_name: []const u8, display_name: []const u8) *CreateApplicationHtmlPageStep {
        const ms = sdk.builder.allocator.create(CreateApplicationHtmlPageStep) catch @panic("out of memory");
        ms.* = CreateApplicationHtmlPageStep{
            .step = std.build.Step.init(.custom, "Create application html page", sdk.builder.allocator, make),

            .sdk = sdk,
            .app_name = sdk.builder.dupe(app_name),
            .display_name = sdk.builder.dupe(display_name),

            .outfile = std.build.GeneratedFile{ .step = &ms.step },
        };
        ms.step.dependOn(&sdk.render_main_page_tool.step);
        return ms;
    }

    fn make(step: *std.build.Step) !void {
        const self = @fieldParentPtr(CreateApplicationHtmlPageStep, "step", step);

        var cache = CacheBuilder.init(self.sdk.builder, "zero-graphics");

        cache.addBytes(self.app_name);
        cache.addBytes(self.display_name);

        const folder_path = try cache.createAndGetPath();

        self.outfile.path = try std.fs.path.join(self.sdk.builder.allocator, &[_][]const u8{
            folder_path,
            "index.htm",
        });

        _ = try self.sdk.builder.execFromStep(&[_][]const u8{
            self.sdk.render_main_page_tool.getOutputSource().getPath(self.sdk.builder),
            self.outfile.path.?,
            self.app_name,
            self.display_name,
        }, step);
    }
};

const CacheBuilder = struct {
    const Self = @This();

    builder: *std.build.Builder,
    hasher: std.crypto.hash.Sha1,
    subdir: ?[]const u8,

    pub fn init(builder: *std.build.Builder, subdir: ?[]const u8) Self {
        return Self{
            .builder = builder,
            .hasher = std.crypto.hash.Sha1.init(.{}),
            .subdir = if (subdir) |s|
                builder.dupe(s)
            else
                null,
        };
    }

    pub fn addBytes(self: *Self, bytes: []const u8) void {
        self.hasher.update(bytes);
    }

    pub fn addFile(self: *Self, file: std.build.FileSource) !void {
        const path = file.getPath(self.builder);

        const data = try std.fs.cwd().readFileAlloc(self.builder.allocator, path, 1 << 32); // 4 GB
        defer self.builder.allocator.free(data);

        self.addBytes(data);
    }

    fn createPath(self: *Self) ![]const u8 {
        var hash: [20]u8 = undefined;
        self.hasher.final(&hash);

        const path = if (self.subdir) |subdir|
            try std.fmt.allocPrint(
                self.builder.allocator,
                "{s}/{s}/o/{}",
                .{
                    self.builder.cache_root,
                    subdir,
                    std.fmt.fmtSliceHexLower(&hash),
                },
            )
        else
            try std.fmt.allocPrint(
                self.builder.allocator,
                "{s}/o/{}",
                .{
                    self.builder.cache_root,
                    std.fmt.fmtSliceHexLower(&hash),
                },
            );

        return path;
    }

    pub const DirAndPath = struct {
        dir: std.fs.Dir,
        path: []const u8,
    };
    pub fn createAndGetDir(self: *Self) !DirAndPath {
        const path = try self.createPath();
        return DirAndPath{
            .path = path,
            .dir = try std.fs.cwd().makeOpenPath(path, .{}),
        };
    }

    pub fn createAndGetPath(self: *Self) ![]const u8 {
        const path = try self.createPath();
        try std.fs.cwd().makePath(path);
        return path;
    }

    pub fn createSingleFile(self: *Self, name: []const u8, data: []const u8) ![]const u8 {
        var dp = try self.createAndGetDir();
        defer dp.dir.close();

        try dp.dir.writeFile(name, data);

        return try std.fs.path.join(self.builder.allocator, &[_][]const u8{
            dp.path,
            name,
        });
    }
};
