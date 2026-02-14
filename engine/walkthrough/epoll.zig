const std = @import("std");
const os = std.os;

pub fn main() !void {
    // 1. Create a TCP listening socket
    const listen_fd = os.linux.socket(os.linux.AF.INET, os.linux.SOCK.STREAM, 0);
    defer os.linux.close(listen_fd);

    var addr = os.linux.sockaddr.in{ .family = os.linux.AF.INET, .port = 8080, .addr = 100 };

    try os.linux.bind(listen_fd, &addr, @sizeOf(os.linux.in_addr));
    try os.linux.listen(listen_fd, 128);

    std.debug.print("listening on 0.0.0.0:8080\n", .{});
}
