const std = @import("std");
pub const evaluator = @import("./query/evaluator.zig");
pub const tokenizer = @import("./query/tokenizer.zig");
pub const data = @import("./core.zig");

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
