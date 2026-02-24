/// This module is responsible for linking modules which contains code.
const std = @import("std");

pub const Module = struct {
    path: []const u8,
    code: []const u8,
};

// this function receives an array of modules as entries, to start with them and parse all import statements and link them all together into one big module.
// It returns multiple string with all the code linked together for every entries, maybe a css module or a js module.
// It supports to stripe typescript syntax, so caller could use typescript syntax in their modules.
pub fn linkModules(allocator: *std.mem.Allocator, entries: []Module) ![]Module {
    for (entries) |module| {
        const code = try std.fs.cwd().readFileAlloc(allocator, module.path, std.math.maxInt(usize));
        defer allocator.free(code);

        var cursor: usize = 0;
        while (cursor < code.len) {
            cursor = peek(code, cursor, "import");
            // try to parse the import clause
            // lookahead for importSpecifiers, a `{` or a `*` or a `'` or a `"` or a alphabet character, orelse return a syntax error.
            if (peek(code, cursor, "{")) |new_cursor| {
                cursor = new_cursor;
                cursor = peek(code, cursor, "}");
            }

            cursor += 1;
        }
    }
}

fn peek(code: []const u8, cursor: usize, pattern: []const u8) usize {
    if (cursor + pattern.len > code.len) return cursor;
    if (std.mem.startsWith(u8, code[cursor..], pattern)) return cursor + pattern.len;
    return cursor;
}
