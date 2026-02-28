/// This module is responsible for linking modules which contains code.
/// Supports recursive linking with post-order traversal.
const std = @import("std");

pub const ModuleLinker = @This();

pub const Module = struct {
    specifier: []const u8,
};

/// Symbol info for linkage
pub const SymbolInfo = struct {
    name: []const u8,
    kind: []const u8,
    binding_source: []const u8,

    pub const StringHashMap = std.StringHashMap(SymbolInfo);
};

/// State for recursive linking
pub const State = struct {
    allocator: std.mem.Allocator,
    output: std.ArrayList(u8),
    linkage_symbol_table: SymbolInfo.StringHashMap,
    linked_modules: std.StringHashMap(bool),
    imported_module_code_export_symbols: std.ArrayList(u8),
    visited: std.StringHashMap(void),
    visiting: std.StringHashMap(void),

    fn init(allocator: std.mem.Allocator) State {
        const state = State{
            .allocator = allocator,
            .output = std.ArrayList(u8).initCapacity(allocator, 1024 * 1024) catch unreachable,
            .linkage_symbol_table = SymbolInfo.StringHashMap.init(allocator),
            .linked_modules = std.StringHashMap(bool).init(allocator),
            .imported_module_code_export_symbols = std.ArrayList(u8).initCapacity(allocator, 1024 * 1024) catch unreachable,
            .visited = std.StringHashMap(void).init(allocator),
            .visiting = std.StringHashMap(void).init(allocator),
        };
        return state;
    }

    fn deinit(self: *State) void {
        self.output.deinit(self.allocator);
        // Free all allocated symbol names
        var it = self.linkage_symbol_table.keyIterator();
        while (it.next()) |key| {
            self.allocator.free(key.*);
        }
        self.linkage_symbol_table.deinit();
        self.linked_modules.deinit();
        self.imported_module_code_export_symbols.deinit(self.allocator);
        self.visited.deinit();
        self.visiting.deinit();
    }
};

// this function receives an array of modules as entries, to start with them and parse all import statements and link them all together into one big module.
// RECURSIVE: Now supports recursive linking with post-order traversal.
pub fn linkModules(allocator: std.mem.Allocator, entries: *[1]Module) !void {
    var state = State.init(allocator);
    defer state.deinit();

    std.debug.print("\n🔗 Starting recursive module linking...\n", .{});

    // Process each entry point with post-order traversal
    for (entries) |module| {
        var buf: [1024]u8 = undefined;
        var buf_parent: [1024]u8 = undefined;
        const path = try resolve(&buf, module.specifier, try std.fs.realpath("./module-linker.zig", &buf_parent));
        std.debug.print("📦 Entry: {s} -> {s}\n", .{ module.specifier, path });

        // RECURSIVE: Visit module and all its dependencies
        try visitModulePostOrder(&state, path);
    }

    std.debug.print("\n✅ Dependency resolution complete. Linked {d} modules:\n", .{state.linked_modules.count()});
    var it = state.linked_modules.keyIterator();
    var i: usize = 0;
    while (it.next()) |key| : (i += 1) {
        std.debug.print("  {d}. {s}\n", .{ i + 1, key.* });
    }

    // Write output
    std.fs.cwd().access("dist", .{ .mode = .read_write }) catch |err| {
        if (err == error.FileNotFound) {
            std.fs.cwd().makeDir("dist") catch unreachable;
        } else {
            return err;
        }
    };
    try std.fs.cwd().writeFile(.{ .data = state.output.items, .sub_path = "dist/output.ts", .flags = .{ .read = true } });
    std.debug.print("✅ Output written to dist/output.ts ({d} bytes)\n", .{state.output.items.len});
}

/// Post-order traversal: visit all dependencies first, then current module
fn visitModulePostOrder(state: *State, path: []const u8) !void {
    // Check if already visited
    if (state.visited.get(path)) |_| {
        std.debug.print("  ⏭️  Already visited: {s}\n", .{path});
        return;
    }

    // Check for circular dependency
    if (state.visiting.get(path)) |_| {
        std.debug.print("⚠️  Circular dependency detected: {s}\n", .{path});
        return;
    }

    // Mark as visiting
    try state.visiting.put(path, {});

    // Read module code
    const code = try std.fs.cwd().readFileAlloc(state.allocator, path, std.math.maxInt(usize));
    defer state.allocator.free(code);

    std.debug.print("  📄 Processing: {s}\n", .{path});

    // Extract and recursively visit all imports BEFORE processing current module
    var cursor: usize = 0;
    cursor = stripWhitespace(code, cursor);
    while (cursor < code.len) {
        if (peek(code, cursor, "import")) {
            cursor += 6;
            cursor = stripWhitespace(code, cursor);

            if (peek(code, cursor, "{")) {
                // Named imports: import { a, b } from './module'
                cursor = skipToClosingBrace(code, cursor);
                cursor = stripWhitespace(code, cursor);

                if (peek(code, cursor, "from")) {
                    cursor += 4;
                    cursor = stripWhitespace(code, cursor);

                    if (peek(code, cursor, "'") or peek(code, cursor, "\"")) {
                        const import_path = try parseModuleSpecifier(code, &cursor, state.allocator);
                        if (import_path) |import_spec| {
                            var buf_path: [1024]u8 = undefined;
                            const resolved_path = try resolve(&buf_path, import_spec, path);
                            std.debug.print("    📥 Import: {s} -> {s}\n", .{ import_spec, resolved_path });

                            // RECURSIVE: Visit dependency first (post-order)
                            try visitModulePostOrder(state, resolved_path);
                        }
                    }
                }
            } else if (peek(code, cursor, "*")) {
                // Namespace import: import * as name from './module'
                cursor += 1;
                cursor = stripWhitespace(code, cursor);
                if (peek(code, cursor, "as")) cursor += 2;
                cursor = skipIdentifier(code, cursor);
                cursor = stripWhitespace(code, cursor);

                if (peek(code, cursor, "from")) {
                    cursor += 4;
                    cursor = stripWhitespace(code, cursor);

                    if (peek(code, cursor, "'") or peek(code, cursor, "\"")) {
                        const import_path = try parseModuleSpecifier(code, &cursor, state.allocator);
                        if (import_path) |import_spec| {
                            var buf_path: [1024]u8 = undefined;
                            const resolved_path = try resolve(&buf_path, import_spec, path);
                            std.debug.print("    📥 Import: {s} -> {s}\n", .{ import_spec, resolved_path });

                            // RECURSIVE
                            try visitModulePostOrder(state, resolved_path);
                        }
                    }
                }
            } else if (peek(code, cursor, "'") or peek(code, cursor, "\"")) {
                // Side-effect import: import './module'
                const import_path = try parseModuleSpecifier(code, &cursor, state.allocator);
                if (import_path) |import_spec| {
                    var buf_path: [1024]u8 = undefined;
                    const resolved_path = try resolve(&buf_path, import_spec, path);
                    std.debug.print("    📥 Import: {s} -> {s}\n", .{ import_spec, resolved_path });

                    // RECURSIVE
                    try visitModulePostOrder(state, resolved_path);
                }
            } else {
                // Default import: import name from './module'
                cursor = skipIdentifier(code, cursor);
                cursor = stripWhitespace(code, cursor);

                if (peek(code, cursor, "from")) {
                    cursor += 4;
                    cursor = stripWhitespace(code, cursor);

                    if (peek(code, cursor, "'") or peek(code, cursor, "\"")) {
                        const import_path = try parseModuleSpecifier(code, &cursor, state.allocator);
                        if (import_path) |import_spec| {
                            var buf_path: [1024]u8 = undefined;
                            const resolved_path = try resolve(&buf_path, import_spec, path);
                            std.debug.print("    📥 Import: {s} -> {s}\n", .{ import_spec, resolved_path });

                            // RECURSIVE
                            try visitModulePostOrder(state, resolved_path);
                        }
                    }
                }
            }
        } else {
            cursor += 1;
        }
        cursor = stripWhitespaceAndComments(code, cursor);
    }

    // AFTER visiting all dependencies, process current module (post-order)
    // Original logic: parse exports, build symbol table, append code
    try processModuleExports(state, code);
    try state.output.appendSlice(state.allocator, code);
    try state.output.appendSlice(state.allocator, "\n\n");

    // Mark as visited
    try state.visited.put(path, {});
    try state.linked_modules.put(path, true);
    std.debug.print("  ✅ Linked: {s}\n", .{path});

    // Remove from visiting
    _ = state.visiting.remove(path);
}

/// Process module exports (original logic extracted)
fn processModuleExports(state: *State, code: []const u8) !void {
    var module_cursor: usize = 0;
    module_cursor = stripWhitespaceAndComments(code, module_cursor);

    while (module_cursor < code.len) {
        if (peek(code, module_cursor, "export")) {
            module_cursor += 6;
            module_cursor = stripWhitespaceAndComments(code, module_cursor);

            if (peek(code, module_cursor, "function")) {
                module_cursor += 8;
                module_cursor = stripWhitespaceAndComments(code, module_cursor);

                const func_name_start = module_cursor;
                while (module_cursor < code.len and
                    (std.ascii.isAlphanumeric(code[module_cursor]) or code[module_cursor] == '_'))
                {
                    module_cursor += 1;
                }

                const func_name = code[func_name_start..module_cursor];
                std.debug.print("    📤 Export function: {s}\n", .{func_name});

                // Find end of function
                var brace_count: usize = 0;
                var in_string: bool = false;
                var string_char: u8 = 0;

                while (module_cursor < code.len) {
                    const char = code[module_cursor];
                    if (in_string) {
                        if (char == string_char and code[module_cursor - 1] != '\\') {
                            in_string = false;
                        }
                    } else {
                        if (char == '"' or char == '\'') {
                            in_string = true;
                            string_char = char;
                        } else if (char == '{') {
                            brace_count += 1;
                        } else if (char == '}') {
                            if (brace_count == 0) break;
                            brace_count -= 1;
                        }
                    }
                    module_cursor += 1;
                }

                const func_name_slice = try state.allocator.dupe(u8, func_name);
                try state.linkage_symbol_table.put(func_name_slice, .{
                    .name = func_name_slice,
                    .kind = "FunctionDeclaration",
                    .binding_source = "",
                });
            }
        }
        module_cursor += 1;
    }
}

fn parseModuleSpecifier(code: []const u8, cursor: *usize, allocator: std.mem.Allocator) !?[]const u8 {
    if (cursor.* >= code.len) return null;

    const quote_char = code[cursor.*];
    if (quote_char != '"' and quote_char != '\'') return null;

    cursor.* += 1;
    const start = cursor.*;

    while (cursor.* < code.len and code[cursor.*] != quote_char) {
        cursor.* += 1;
    }

    if (cursor.* >= code.len) return null;

    const specifier = try allocator.dupe(u8, code[start..cursor.*]);
    cursor.* += 1;

    return specifier;
}

fn skipToClosingBrace(code: []const u8, cursor: usize) usize {
    var i = cursor;
    var brace_count: usize = 0;
    while (i < code.len) {
        if (code[i] == '{') brace_count += 1;
        if (code[i] == '}') {
            if (brace_count == 0) return i;
            brace_count -= 1;
        }
        i += 1;
    }
    return i;
}

fn skipIdentifier(code: []const u8, cursor: usize) usize {
    var i = cursor;
    while (i < code.len and (std.ascii.isAlphanumeric(code[i]) or code[i] == '_')) {
        i += 1;
    }
    return i;
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
        return resolved.items;
    }
    return specifier;
}

fn peek(code: []const u8, cursor: usize, pattern: []const u8) bool {
    if (cursor + pattern.len > code.len) return false;
    if (std.mem.startsWith(u8, code[cursor..], pattern)) return true;
    return false;
}

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
            while (i < code.len and code[i] != '\n') i += 1;
            continue;
        } else if (peek(code, i, "/*")) {
            i += 2;
            while (i < code.len and !peek(code, i, "*/")) i += 1;
            i += 2;
            continue;
        }
        break;
    }
    return i;
}

test "link modules recursively" {
    var entries = [_]Module{Module{ .specifier = "./usecase/main.ts" }};
    try linkModules(std.testing.allocator, &entries);
}
