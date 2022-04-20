const std = @import("std");
const http = @import("apple_pie");
const file_server = http.FileServer;

pub const io_mode = .evented;

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 2) {
        std.log.err("Missing argument: Application name!", .{});
        return 1;
    }

    const application_name = args[1];

    try file_server.init(allocator, .{ .dir_path = "." });
    defer file_server.deinit();

    std.log.info("Application is now served at http://127.0.0.1:8000/{s}.htm", .{application_name});

    try http.listenAndServe(
        allocator,
        try std.net.Address.parseIp("127.0.0.1", 8000),
        {},
        file_server.serve,
    );

    return 0;
}
