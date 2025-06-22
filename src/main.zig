const std = @import("std");
pub const evaluator = @import("./evaluator.zig");
pub const tokenizer = @import("./tokenizer.zig");
pub const data = @import("./base.zig");

pub fn main() !void {
    var iter = try std.process.argsWithAllocator(std.heap.page_allocator);
    std.debug.print("Base address is 0x{x}", .{std.process.getBaseAddress()});
    // skip the first argument
    _ = iter.skip();

    if (iter.next()) |dql| {
        std.debug.print("\nAccept dql: {s}", .{dql});
        _ = try tokenizer.tokenize(dql);
    } else {
        std.debug.print("No arguments provided.\n", .{});
    }
}
