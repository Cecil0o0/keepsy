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
