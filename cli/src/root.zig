//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

pub fn printLarkCharacters() !void {
    const lark_banner =
        \\LL      AAA   RRRR   K   K
        \\LL     A   A  R   R  K  K 
        \\LL     AAAAA  RRRR   KKK  
        \\LL     A   A  R  R   K  K 
        \\LLLLLL A   A  R   R  K   K
        \\                          
    ;
    std.debug.print(lark_banner, .{});
}
