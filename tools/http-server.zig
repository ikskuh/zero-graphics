const std = @import("std");
const http = @import("apple_pie");
const file_server = http.FileServer;

pub const io_mode = .evented;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = &gpa.allocator;

    try file_server.init(allocator, .{ .dir_path = "www" });
    defer file_server.deinit();

    std.log.info("Application is now served at http://127.0.0.1:8000/index.htm", .{});

    try http.listenAndServe(
        allocator,
        try std.net.Address.parseIp("127.0.0.1", 8000),
        file_server.serve,
    );
}
