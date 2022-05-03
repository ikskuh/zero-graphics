const std = @import("std");
const args_parser = @import("args");

fn printUsage(exe_name: []const u8, stream: anytype) !void {
    try stream.print("{s} <mode> [--help] [--git]\n", .{
        std.fs.path.basename(exe_name),
    });
    try stream.writeAll(
        \\Initializes a new zero-graphics project with the given mode.
        \\  <mode> is the mode with which zero-graphics is initialized:
        \\    basic:     just create a empty folder vendor/zero-graphics that must be filled manually
        \\    submodule: installs zero-graphics as a submodule dependency. Implies --git.
        \\    symlink:   will add vendor/zero-graphics as a symlink to the source repository.
        \\
        \\  -h, --help   Shows this help text.
        \\  -g, --git    Also initializes a fresh git repository for your project.
        \\
    );
}

const InitMode = enum {
    basic, // create an empty folder
    submodule, // adds zero-graphics as a submodule, implies --git
    symlink, // create a symlink relative to this exe
    // zigmod, // possible future feature
    // gyro, // possible future feature
};

const CliArgs = struct {
    help: bool = false,
    git: bool = false,

    pub const shorthands = .{
        .h = "help",
        .g = "git",
    };
};

const FileSystemEntry = struct {
    path: []const u8,
    contents: EntryData,
    flags: Flags = .{},

    const EntryData = union(enum) {
        directory,
        file: []const u8,
    };
    const Flags = struct {
        git_only: bool = false,
    };
};

const file_system_image = [_]FileSystemEntry{
    FileSystemEntry{ .path = "src/", .contents = .directory },
    FileSystemEntry{ .path = "vendor/", .contents = .directory },
    FileSystemEntry{ .path = "build.zig", .contents = .{ .file = @embedFile("template/build.zig") } },
    FileSystemEntry{ .path = "src/main.zig", .contents = .{ .file = @embedFile("template/src/main.zig") } },
    FileSystemEntry{ .path = ".gitignore", .contents = .{ .file = @embedFile("template/gitignore") }, .flags = .{ .git_only = true } },
    FileSystemEntry{ .path = ".gitattributes", .contents = .{ .file = @embedFile("template/gitattributes") }, .flags = .{ .git_only = true } },
};

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

fn exec(cwd: []const u8, argv: []const []const u8) !void {
    var proc = std.ChildProcess.init(argv, allocator);

    proc.cwd = cwd;

    const term = try proc.spawnAndWait();

    if (term != .Exited and term.Exited != 0) {
        return error.InvalidExitCode;
    }
}

pub fn main() !u8 {
    defer _ = gpa.deinit();

    var cli = args_parser.parseForCurrentProcess(CliArgs, allocator, .print) catch return 1;
    defer cli.deinit();

    var stdout = std.io.getStdOut();
    var stderr = std.io.getStdErr();

    if (cli.options.help) {
        try printUsage(cli.executable_name.?, stdout.writer());
        return 1;
    }

    if (cli.positionals.len != 1) {
        try printUsage(cli.executable_name.?, stderr.writer());
        return 1;
    }

    const mode = std.meta.stringToEnum(InitMode, cli.positionals[0]) orelse {
        try stderr.writer().print("unknown mode: {s}\n", .{cli.positionals[0]});
        return 1;
    };

    if (mode == .submodule) {
        cli.options.git = true;
    }

    var dir = try std.fs.cwd().openDir(".", .{});
    defer dir.close();

    for (file_system_image) |entry| {
        if (entry.flags.git_only) {
            if (!cli.options.git)
                continue;
        }

        const path = entry.path;
        switch (entry.contents) {
            .directory => try dir.makePath(path),
            .file => |contents| {
                if (std.fs.path.dirname(path)) |child_dir| {
                    try dir.makePath(child_dir);
                }
                try dir.writeFile(path, contents);
            },
        }
    }

    if (cli.options.git) {
        exec(".", &[_][]const u8{
            "git", "init",
        }) catch return 1;
    }

    switch (mode) {
        .basic => {
            try dir.makeDir("vendor/zero-graphics");
        },
        .submodule => {
            // as submodule implies this, we make sure
            std.debug.assert(cli.options.git);

            exec(".", &[_][]const u8{
                "git", "submodule", "init",
            }) catch return 1;
            exec("vendor", &[_][]const u8{
                "git", "submodule", "add", "https://github.com/MasterQ32/zero-graphics",
            }) catch return 1;
            exec(".", &[_][]const u8{
                "git", "submodule", "update", "--init", "--recursive",
            }) catch return 1;
        },
        .symlink => {
            const real_path = try std.fs.realpathAlloc(allocator, std.fs.path.dirname(cli.executable_name.?) orelse ".");
            defer allocator.free(real_path);

            const zig_out_dir = std.fs.path.dirname(real_path) orelse real_path;
            const root_dir = std.fs.path.dirname(zig_out_dir) orelse zig_out_dir;

            try dir.symLink(root_dir, "vendor/zero-graphics", .{ .is_directory = true });
        },
    }

    return 0;
}
