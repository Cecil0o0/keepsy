/// This module is responsible for linking modules which contains code.
const std = @import("std");

pub const Module = struct {
    specifier: []const u8,
};

// this function receives an array of modules as entries, to start with them and parse all import statements and link them all together into one big module.
// It returns multiple string with all the code linked together for every entries, maybe a css module or a js module.
// It supports to stripe typescript syntax, so module could contains typescript code.
pub fn linkModules(allocator: std.mem.Allocator, entries: *[1]Module) !void {
    for (entries) |module| {
        var buf: [1024]u8 = undefined;
        var buf_parent: [1024]u8 = undefined;
        const path = try resolve(&buf, module.specifier, try std.fs.realpath("./module-linker.zig", &buf_parent));
        std.debug.print("Resolved {s} to {s}\n", .{ module.specifier, path });
        const code = try std.fs.cwd().readFileAlloc(allocator, path, std.math.maxInt(usize));
        defer allocator.free(code);

        // allocate for output module.
        // 1MB for initialization, and it can grow up automatically.
        var output = try std.ArrayList(u8).initCapacity(allocator, 1024 * 1024);
        defer output.deinit(allocator);
        // allocate for symbol table.
        var symbol_table = std.AutoHashMap([]const u8, struct { name: []const u8 }).init(allocator);
        defer symbol_table.deinit();

        var cursor: usize = 0;
        var end_of_linking_cursor: usize = 0;
        cursor = stripWhitespace(code, cursor);
        while (cursor < code.len) {
            if (peek(code, cursor, "import")) {
                cursor += 6;
                // try to parse importDeclaration
                cursor = stripWhitespace(code, cursor);
                if (peek(code, cursor, "{")) {
                    cursor += 1;
                    // try to parse NamedImports in ImportClause
                    cursor = stripWhitespace(code, cursor);
                    var buf_NamedImports: [512]u8 = undefined;
                    var NamedImports = std.ArrayList(u8).initBuffer(&buf_NamedImports);
                    while (cursor < code.len and code[cursor] != '}') {
                        NamedImports.append(allocator, code[cursor]) catch |err| {
                            switch (err) {
                                error.OutOfMemory => return error.syntaxError,
                                else => return err,
                            }
                        };
                        cursor += 1;
                    }
                    cursor += 1;
                    std.debug.print("NamedImports: {s}\n", .{NamedImports.items});

                    // try to parse FromClause
                    cursor = stripWhitespace(code, cursor);
                    if (peek(code, cursor, "from")) {
                        cursor += 4;
                        // try to parse ModuleSpecifier in FromClause
                        cursor = stripWhitespace(code, cursor);
                        if (peek(code, cursor, "'")) {
                            cursor += 1;
                            var buf_ModuleSpecifier: [64]u8 = undefined;
                            var ModuleSpecifier = std.ArrayList(u8).initBuffer(&buf_ModuleSpecifier);
                            while (cursor < code.len and code[cursor] != '\'') {
                                ModuleSpecifier.append(allocator, code[cursor]) catch |err| {
                                    switch (err) {
                                        std.mem.Allocator.Error.OutOfMemory => return error.syntaxError,
                                        else => return err,
                                    }
                                };
                                cursor += 1;
                            }
                            cursor += 1;
                            std.debug.print("ModuleSpecifier: {s}\n", .{ModuleSpecifier.items});
                            var buf_path_to_file: [1024]u8 = undefined;
                            const path_to_file = try resolve(&buf_path_to_file, ModuleSpecifier.items, path);
                            std.debug.print("Resolved {s} to {s}\n", .{ ModuleSpecifier.items, path_to_file });
                            const module_code = try std.fs.cwd().readFileAlloc(allocator, path_to_file, std.math.maxInt(usize));
                            defer allocator.free(module_code);
                            try output.appendSlice(allocator, module_code);
                            continue;
                        }
                    }
                    cursor = stripWhitespace(code, cursor);
                }
            }

            if (peek(code, cursor, ";")) {
                cursor += 1;
                cursor = stripWhitespaceAndComments(code, cursor);
                if (!peek(code, cursor, "import")) {
                    end_of_linking_cursor = cursor;
                    break;
                } else continue;
            }
            cursor += 1;
        }

        try output.appendSlice(allocator, code[end_of_linking_cursor..]);
        std.fs.cwd().access("dist", .{ .mode = .read_write }) catch |err| {
            if (err == error.FileNotFound) {
                try std.fs.cwd().makeDir("dist");
            } else {
                return err;
            }
        };
        try std.fs.cwd().writeFile(.{ .data = output.items, .sub_path = "dist/output.ts", .flags = .{ .read = true } });
    }
}

fn resolve(buf: []u8, specifier: []const u8, parent: []const u8) ![]const u8 {
    if (std.mem.startsWith(u8, specifier, "./") or std.mem.startsWith(u8, specifier, "../")) {
        var parent_count: u8 = 0;
        var cursor_specifier: u8 = 0;
        while (cursor_specifier < specifier.len) {
            if (peek(specifier, cursor_specifier, "../")) {
                parent_count += 1;
                cursor_specifier += 3;
            } else if (peek(specifier, cursor_specifier, "./")) {
                cursor_specifier += 2;
            } else break;
        }
        var dirname = std.fs.path.dirname(parent).?;
        var i = dirname.len;
        if (parent_count == 0) {} else {
            i = i - 1;
            while (i > 0) {
                if (dirname[i] == '/') {
                    parent_count -= 1;
                    if (parent_count == 0) break;
                }
                i -= 1;
            }
        }
        var resolved = std.ArrayList(u8).initBuffer(buf);
        try resolved.appendSliceBounded(dirname[0..i]);
        try resolved.appendBounded('/');
        try resolved.appendSliceBounded(specifier[cursor_specifier..]);
        std.debug.print("Resolved path: {s}\n", .{resolved.items});
        return resolved.items;
    }
    return specifier;
}

// returns true if the code starting at cursor position matches the pattern
fn peek(code: []const u8, cursor: usize, pattern: []const u8) bool {
    if (cursor + pattern.len > code.len) return false;
    if (std.mem.startsWith(u8, code[cursor..], pattern)) return true;
    return false;
}

// strip often refers to removing non-essential characters from the source code before parsing begins
fn stripWhitespace(code: []const u8, cursor: usize) usize {
    var i = cursor;
    while (i < code.len) {
        if (std.ascii.isWhitespace(code[i])) i += 1 else break;
    }
    return i;
}

fn stripWhitespaceAndComments(code: []const u8, cursor: usize) usize {
    var i = cursor;
    while (i < code.len) {
        if (std.ascii.isWhitespace(code[i])) {
            i += 1;
            continue;
        } else if (peek(code, i, "//")) {
            i += 2;
            // strip line comment
            while (i < code.len and code[i] != '\n') i += 1;
            continue;
        } else if (peek(code, i, "/*")) {
            i += 2;
            // strip block comment
            while (i < code.len and !peek(code, i, "*/")) i += 1;
            i += 2;
            continue;
        }
        break;
    }
    return i;
}

test "link modules" {
    var entries = [_]Module{Module{ .specifier = "./usecase/main.ts" }};
    _ = try linkModules(std.testing.allocator, &entries);
}
