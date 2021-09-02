const std = @import("std");
const html = @import("html");

// {exe} target_file application_name display_name
pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    if (args.len != 4) @panic("invalid number of arguments!");

    var f = try std.fs.cwd().createFile(args[1], .{});
    defer f.close();

    try html.render(f.writer(), .{
        .app_name = args[2],
        .display_name = args[3],
    });
}
