const std = @import("std");
const args_parser = @import("args");

const CliArgs = struct {
    symlink: bool = false,
    submodule: bool = false,
    git: bool = false,
};

const file_system_image = .{
    .@"src/" = .directory,
    .@"vendor/" = .directory,
    .@"build.zig" = @embedFile("template/build.zig"),
    .@"src/main.zig" = @embedFile("template/src/main.zig"),
    .@".gitignore" = @embedFile("template/gitignore"),
    .@".gitattributes" = @embedFile("template/gitattributes"),
};

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = &gpa.allocator;

fn exec(cwd: []const u8, argv: []const []const u8) !void {
    var proc = try std.ChildProcess.init(argv, allocator);
    defer proc.deinit();

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

    if (cli.options.submodule and cli.options.symlink) {
        try std.io.getStdErr().writeAll("only submodule OR symlink are allowed for init!\r\n");
        return 1;
    }

    var dir = std.fs.cwd();
    inline for (std.meta.fields(@TypeOf(file_system_image))) |fld| {
        const path = fld.name;
        const data = @field(file_system_image, path);
        if (path[path.len - 1] == '/') {
            try dir.makePath(path);
        } else {
            if (std.fs.path.dirname(path)) |child_dir| {
                try dir.makePath(child_dir);
            }
            try dir.writeFile(path, data);
        }
    }

    if (cli.options.git) {
        exec(".", &[_][]const u8{
            "git", "init",
        }) catch return 1;
        if (cli.options.submodule) {
            exec(".", &[_][]const u8{
                "git", "submodule", "init",
            }) catch return 1;
            exec("vendor", &[_][]const u8{
                "git", "submodule", "add", "https://github.com/MasterQ32/zero-graphics",
            }) catch return 1;
            exec(".", &[_][]const u8{
                "git", "submodule", "update", "--init", "--recursive",
            }) catch return 1;
        }
    }

    if (cli.options.symlink) {
        const real_path = try std.fs.realpathAlloc(allocator, std.fs.path.dirname(cli.executable_name.?) orelse ".");
        defer allocator.free(real_path);

        const zig_out_dir = std.fs.path.dirname(real_path) orelse real_path;
        const root_dir = std.fs.path.dirname(zig_out_dir) orelse zig_out_dir;

        try dir.symLink(root_dir, "vendor/zero-graphics", .{ .is_directory = true });
    }

    return 0;
}
