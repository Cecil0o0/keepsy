const std = @import("std");
pub fn main() void {
    var buf: [128]u8 = undefined;
    var al = std.ArrayList(u8).initBuffer(&buf);
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();
    al.appendSlice(gpa.allocator(), "Hello, \n") catch unreachable;
    al.insertSlice(gpa.allocator(), 0, "Inserted Memory\n") catch unreachable;

    std.debug.print("{s}", .{al.items});
}
