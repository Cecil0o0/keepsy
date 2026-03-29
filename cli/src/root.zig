//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

pub fn printLarkCharacters() !void {
    const lark_banner =
        \\
        \\####### ###### #  ####  #    # #    #
        \\#       #      # #      #    # #    #
        \\#####   #####  #  ####  ###### #    #
        \\#       #      #      # #    # #    #
        \\#       #      # #    # #    # #    #
        \\#       ###### #  ####  #    #  ####
        \\                          
    ;
    std.debug.print(lark_banner, .{});
}

pub fn printEnv(allocator: std.mem.Allocator) !void {
    var env_map = try std.process.getEnvMap(allocator);
    defer env_map.deinit();

    var iter = env_map.iterator();
    while (iter.next()) |entry| {
        std.debug.print("{s}={s}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
    }
}
