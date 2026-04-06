/// This module is responsible for linking modules which contains code.
/// case guidance
/// snake_case if it's a function or variable name
/// strict follow when the term appears in ecma262, refernce: https://tc39.es/ecma262/#sec-ecmascript-language-scripts-and-modules
/// else do as you like
const std = @import("std");

pub const ModuleLinker = @This();

pub const Module = struct {
    // Module Location = resolve(specifier, parent_path)
    specifier: []const u8,
    parent_path: []const u8,
    resolved_path: ?[]const u8 = null,
    raw_code: ?[]const u8 = "",
};

const Node = struct {
    childLeftNodes: std.ArrayList(Node),
    childRightNodes: std.ArrayList(Node),
    module: Module,
    allocator: std.mem.Allocator,
    state: *State,

    fn init(allocator: std.mem.Allocator, state: *State, module: Module) !Node {
        return Node{
            .childLeftNodes = try std.ArrayList(Node).initCapacity(allocator, 1024),
            .childRightNodes = try std.ArrayList(Node).initCapacity(allocator, 1024),
            .module = module,
            .allocator = allocator,
            .state = state,
        };
    }

    fn deinit(self: *Node) void {
        self.childLeftNodes.deinit(self.allocator);
        self.childRightNodes.deinit(self.allocator);
        if (self.module.resolved_path) |path| self.allocator.free(path);
        if (self.module.raw_code) |code| self.allocator.free(code);
    }
};

/// In computer science, a symbol is an identifier used by Linker to manage and resolve references between separately compiled modules of code.
/// It serves as the fundamental abstraction that allows distinct object files to be combined into a single executable or library.
pub const Symbol = struct {
    // the value of ModuleExportName, ImportedDefaultBiding
    name: ?[]const u8 = "",
    // "VariableDeclaration", "LexicalDeclaration", "FunctionDeclaration", "ClassDeclaration"
    kind: ?[]const u8 = "",
    // to detect if the symbol is a const LexicalDeclaration
    is_const: ?bool = null,
    // This indicates the visible scope of the symbol, such as `Global`, `Module`, or `Local`
    // Symbol would be resolvable only if it is in the correct scope
    binding: ?[]const u8 = "",
    // "import", "export"
    linkage: ?[]const u8 = "import",
    // "ImportedBinding", "ModuleExportName"
    @"[[LinkKind]]": []const u8,
    @"[[ImportedBindingValue]]": []const u8,
};

/// State for module linking
pub const State = struct {
    allocator: std.mem.Allocator,
    output: std.ArrayList(u8),
    symbol_table: std.StringHashMap(Symbol),
    linked_modules: std.StringHashMap(bool),
    imported_module_code_export_symbols: std.ArrayList(u8),

    fn init(allocator: std.mem.Allocator) !State {
        return State{
            .allocator = allocator,
            .output = try std.ArrayList(u8).initCapacity(allocator, 1024 * 1024),
            // String is the ModuleExportName, it would be a semantic slice to get the symbol
            .symbol_table = std.StringHashMap(Symbol).init(allocator),
            .linked_modules = std.StringHashMap(bool).init(allocator),
            .imported_module_code_export_symbols = try std.ArrayList(u8).initCapacity(allocator, 1024 * 1024),
        };
    }

    fn deinit(self: *State) void {
        self.output.deinit(self.allocator);
        var iter = self.symbol_table.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            if (entry.value_ptr.@"[[ImportedBindingValue]]".len > 0) self.allocator.free(entry.value_ptr.@"[[ImportedBindingValue]]");
        }
        self.symbol_table.deinit();
        self.linked_modules.deinit();
        self.imported_module_code_export_symbols.deinit(self.allocator);
    }
};

// this function receives an array of modules as entries, to start with them and parse all import statements and link them all together into one big module.
// It returns multiple string with all the code linked together for every entries, maybe a css module or a js module.
// It supports to stripe typescript syntax, so module could contains typescript code.
pub fn link_modules(allocator: std.mem.Allocator, entries: *[1]Module) !void {
    var state = try State.init(allocator);
    defer state.deinit();

    for (entries) |module| {
        var buf_parent: [1024]u8 = undefined;
        const path = try resolve(allocator, module.specifier, std.fs.realpath(module.parent_path, &buf_parent) catch |err| {
            switch (err) {
                error.FileNotFound => {
                    const cwd = try std.fs.cwd().realpathAlloc(allocator, ".");
                    defer allocator.free(cwd);
                    std.debug.print("CWD: {s}, File not found: {s}, {s}\n", .{ cwd, module.specifier, module.parent_path });
                    @panic("Module not resolved.");
                },
                else => {
                    return err;
                },
            }
        });
        const code = try std.fs.cwd().readFileAlloc(state.allocator, path, std.math.maxInt(usize));
        // code will be freed by tree cleanup via freeNode

        // Build module tree using buildModuleTree
        const root_module = Module{
            .specifier = module.specifier,
            .parent_path = module.parent_path,
            .resolved_path = path,
            .raw_code = code,
        };
        var root_node = try build_module_tree(allocator, &state, root_module);
        defer post_order_traverse(&root_node, free_node) catch |err| {
            std.debug.print("Error when freeing node: {any}\n", .{err});
        };

        // Traverse tree in post-order to process dependencies before dependents
        try post_order_traverse(&root_node, visit_node);

        std.fs.cwd().access("dist", .{ .mode = .read_write }) catch |err| {
            if (err == error.FileNotFound) {
                try std.fs.cwd().makeDir("dist");
            } else {
                return err;
            }
        };
        try std.fs.cwd().writeFile(.{ .data = state.output.items, .sub_path = "dist/output.ts", .flags = .{ .read = true } });
    }
}

fn visit_node(node: *Node) !void {
    std.debug.print("   🌲 Processing module: {s}\n", .{node.module.specifier});
    const module = node.module;
    const state = node.state;
    const code = module.raw_code.?;
    var cursor: usize = 0;
    var end_of_linking_cursor: usize = 0;
    cursor = strip_whitespace(code, cursor);
    end_of_linking_cursor = cursor;

    var linked_code = try std.ArrayList(u8).initCapacity(node.allocator, 1024 * 1024);
    defer linked_code.deinit(node.allocator);
    // intermediate code for debugging linkage
    try linked_code.appendSlice(node.allocator, "\n// ");
    try linked_code.appendSlice(node.allocator, module.resolved_path.?);
    try linked_code.appendSlice(node.allocator, "\n\n");

    while (cursor < code.len) {
        if (peek(code, cursor, "import")) {
            // start to link
            cursor += 6;
            // try to parse importDeclaration
            cursor = strip_whitespace(code, cursor);
            if (peek(code, cursor, "{")) {
                cursor += 1;
                cursor = strip_whitespace(code, cursor);
                // try toconsume NamedImports in ImportClause
                var buf_NamedImports: [512]u8 = undefined;
                var NamedImports = std.ArrayList(u8).initBuffer(&buf_NamedImports);
                while (cursor < code.len and code[cursor] != '}') {
                    NamedImports.append(state.allocator, code[cursor]) catch |err| {
                        switch (err) {
                            error.OutOfMemory => return error.syntaxError,
                            else => return err,
                        }
                    };
                    cursor += 1;
                }
                cursor += 1;
                std.debug.print("   📥 imports {{ {s} }}\n", .{NamedImports.items});
                // support ModuleExportName as ImportedBinding
                // In this case: import { a as b }, a is ModuleExportName whereas b is ImportedBinding
                // reference: https://tc39.es/ecma262/#prod-ImportedBinding

                var cursor_NamedImports: usize = 0;
                cursor_NamedImports = strip_whitespace(NamedImports.items, cursor_NamedImports);
                while (cursor_NamedImports < NamedImports.items.len) {
                    if (peek_identifier(NamedImports.items, cursor_NamedImports)) {
                        const ModuleExportName = consume_identifier(NamedImports.items, &cursor_NamedImports);
                        const ModuleExportNameCopy = try state.allocator.dupe(u8, ModuleExportName);
                        cursor_NamedImports = strip_whitespace(NamedImports.items, cursor_NamedImports);
                        if (peek(NamedImports.items, cursor_NamedImports, "as")) {
                            cursor_NamedImports += 2;
                            cursor_NamedImports = strip_whitespace(NamedImports.items, cursor_NamedImports);
                            // cosume an identifier
                            const ImportedBinding = consume_identifier(NamedImports.items, &cursor_NamedImports);
                            const ImportedBindingCopy = try state.allocator.dupe(u8, ImportedBinding);
                            try state.symbol_table.put(ImportedBindingCopy, .{
                                .@"[[LinkKind]]" = "ImportedBinding",
                                .@"[[ImportedBindingValue]]" = ModuleExportNameCopy,
                            });
                        } else {
                            try state.symbol_table.put(ModuleExportNameCopy, .{
                                .@"[[LinkKind]]" = "ModuleExportName",
                                .@"[[ImportedBindingValue]]" = "",
                            });
                            std.debug.print("   📥📥📥📥 {s}\n", .{ModuleExportName});
                        }
                        cursor_NamedImports = strip_whitespace(NamedImports.items, cursor_NamedImports);
                        if (peek(code, cursor_NamedImports, ",")) {
                            cursor_NamedImports += 1;
                            cursor_NamedImports = strip_whitespace(NamedImports.items, cursor_NamedImports);
                            continue;
                        }
                    }
                    cursor_NamedImports += 1;
                }

                // try to parse FromClause
                cursor = strip_whitespace(code, cursor);
                if (peek(code, cursor, "from")) {
                    cursor += 4;
                    // try to parse ModuleSpecifier in FromClause
                    cursor = strip_whitespace(code, cursor);
                    if (peek(code, cursor, "'")) {
                        cursor += 1;
                        var buf_ModuleSpecifier: [64]u8 = undefined;
                        var ModuleSpecifier = std.ArrayList(u8).initBuffer(&buf_ModuleSpecifier);
                        while (cursor < code.len) {
                            if (code[cursor] == '\'') {
                                break;
                            }
                            ModuleSpecifier.append(state.allocator, code[cursor]) catch |err| {
                                switch (err) {
                                    std.mem.Allocator.Error.OutOfMemory => return error.syntaxError,
                                    else => return err,
                                }
                            };
                            cursor += 1;
                        }
                        cursor += 1;
                        if (state.linked_modules.contains(ModuleSpecifier.items)) {
                            // same module already linked, don't link again.
                        } else {
                            try state.linked_modules.put(ModuleSpecifier.items, true);
                            const path_to_file = try resolve(node.allocator, ModuleSpecifier.items, module.resolved_path.?);
                            defer node.allocator.free(path_to_file);
                            const module_code = try std.fs.cwd().readFileAlloc(state.allocator, path_to_file, std.math.maxInt(usize));
                            defer node.allocator.free(module_code);
                            // parse ExportDeclaration
                            // parse Declaration
                            // parse HoistableDeclaration
                            // parse FunctionDeclaration
                            // reference: https://tc39.es/ecma262/#prod-ExportSpecifier
                            var module_cursor: usize = 0;
                            module_cursor = strip_whitespace_comments(module_code, module_cursor);

                            while (module_cursor < module_code.len) {
                                if (peek(module_code, module_cursor, "export")) {
                                    module_cursor += 6;
                                    module_cursor = strip_whitespace_comments(module_code, module_cursor);

                                    if (peek(module_code, module_cursor, "function")) {
                                        module_cursor += 8;
                                        module_cursor = strip_whitespace_comments(module_code, module_cursor);

                                        // consume function name
                                        const func_name = consume_identifier(module_code, &module_cursor);
                                        std.debug.print("   ✨ export function {s}\n", .{func_name});

                                        // Find the end of the function declaration
                                        var brace_count: usize = 0;
                                        var in_string: bool = false;
                                        var string_char: u8 = 0;

                                        while (module_cursor < module_code.len) {
                                            const char = module_code[module_cursor];

                                            if (in_string) {
                                                // in_string condition
                                                if (char == string_char and module_code[module_cursor - 1] != '\\') {
                                                    in_string = false;
                                                }
                                            } else {
                                                if (char == '"' or char == '\'') {
                                                    in_string = true;
                                                    string_char = char;
                                                } else if (char == '{') {
                                                    // strip FunctionBody
                                                    brace_count += 1;
                                                } else if (char == '}') {
                                                    if (brace_count == 0) {
                                                        // We've reached the end of the function body
                                                        break;
                                                    }
                                                    brace_count -= 1;
                                                }
                                            }
                                            module_cursor += 1;
                                        }

                                        // Add function to symbol table
                                        const func_name_slice_start = state.imported_module_code_export_symbols.items.len;
                                        state.imported_module_code_export_symbols.appendSlice(state.allocator, func_name) catch |err| {
                                            switch (err) {
                                                std.mem.Allocator.Error.OutOfMemory => return error.syntaxError,
                                                else => return err,
                                            }
                                        };
                                        const func_name_slice = state.imported_module_code_export_symbols.items[func_name_slice_start..];
                                        try state.symbol_table.put(func_name_slice, .{
                                            .@"[[LinkKind]]" = "FunctionDeclaration",
                                            .@"[[ImportedBindingValue]]" = "",
                                        });
                                    }
                                }

                                module_cursor += 1;
                            }
                        }
                        continue;
                    }
                }
                cursor = strip_whitespace(code, cursor);
            }
        } else if (peek(code, cursor, ";")) {
            // end to link
            cursor += 1;
            cursor = strip_whitespace_comments(code, cursor);
            if (!peek(code, cursor, "import")) {
                end_of_linking_cursor = cursor;
                break;
            } else continue;
        } else {
            // no need to link
            break;
        }
        cursor += 1;
    }
    // write binding code by exported FunctionDeclaration
    var iter = state.symbol_table.iterator();
    while (iter.next()) |entry| {
        std.debug.print("   🔗🔗🔗 {s} ({s}) from {s}\n", .{ entry.key_ptr.*, entry.value_ptr.@"[[LinkKind]]", entry.value_ptr.@"[[ImportedBindingValue]]" });
        if (std.mem.eql(u8, entry.value_ptr.@"[[LinkKind]]", "ImportedBinding")) {
            try linked_code.appendSlice(state.allocator, "\n// Define an immutable ImportedBinding here");
            try linked_code.appendSlice(state.allocator, "\nconst ");
            try linked_code.appendSlice(state.allocator, entry.key_ptr.*);
            try linked_code.appendSlice(state.allocator, " = ");
            try linked_code.appendSlice(state.allocator, entry.value_ptr.@"[[ImportedBindingValue]]");
            try linked_code.appendSlice(state.allocator, ";\n");
        }
    }
    const stripped_code = try strip_typescript(node.allocator, code, end_of_linking_cursor);
    defer node.allocator.free(stripped_code);
    try linked_code.appendSlice(node.allocator, stripped_code);
    try state.output.appendSlice(node.allocator, linked_code.items);
}

fn build_module_tree(allocator: std.mem.Allocator, state: *State, module: Module) !Node {
    var node = try Node.init(allocator, state, module);
    const code = module.raw_code.?;

    var cursor: usize = 0;
    pass_import: while (cursor < code.len) {
        cursor = strip_whitespace_comments(code, cursor);
        if (peek(code, cursor, "import")) {
            cursor += 6;
            cursor = strip_whitespace(code, cursor);
            // Althrough there is no need for now to consume the `ImportClause` cause I just want to find the `from` keyword for `FromClause`.
            // but I should consume it to make the syntax correct
            while (cursor < code.len) {
                cursor += 1;
                if (peek(code, cursor, "from")) break;
            }
            if (peek(code, cursor, "from")) {
                cursor += 4;
                cursor = strip_whitespace(code, cursor);
                // try to consume the string literal for path
                // only need to consider single quote cause the purpose of education
                if (peek(code, cursor, "'")) {
                    cursor += 1;
                }
                var string_literal_cursor = cursor;
                while (code[string_literal_cursor] != '\'') {
                    string_literal_cursor += 1;
                }
                const dependency_module_specifier = code[cursor..string_literal_cursor];
                // '\'' and ';'
                cursor = string_literal_cursor + 2;
                const resolved_path = try resolve(allocator, dependency_module_specifier, module.resolved_path.?);
                // if a node with the same `resolved_path` already exists, reuse it
                for (node.childLeftNodes.items) |child_node| {
                    if (std.mem.eql(u8, child_node.module.resolved_path.?, resolved_path)) {
                        allocator.free(resolved_path);
                        continue :pass_import;
                    }
                }
                const dependency_module = Module{
                    .specifier = dependency_module_specifier,
                    .parent_path = module.resolved_path.?,
                    .resolved_path = resolved_path,
                    .raw_code = try std.fs.cwd().readFileAlloc(allocator, resolved_path, std.math.maxInt(usize)),
                };
                try node.childLeftNodes.append(allocator, try build_module_tree(allocator, state, dependency_module));
            }
        } else {
            // peek and pass the `ImportDeclaration`, or else I will break the while loop
            break;
        }
    }
    return node;
}

fn post_order_traverse(node: *Node, visit: fn (node: *Node) anyerror!void) !void {
    for (0..node.childLeftNodes.items.len) |i| {
        try post_order_traverse(&node.childLeftNodes.items[i], visit);
    }
    for (0..node.childRightNodes.items.len) |i| {
        try post_order_traverse(&node.childRightNodes.items[i], visit);
    }
    try visit(node);
}

fn resolve(allocator: std.mem.Allocator, specifier: []const u8, parent: []const u8) ![]const u8 {
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
        var resolved = try std.ArrayList(u8).initCapacity(allocator, 1024);
        try resolved.appendSliceBounded(dirname[0..i]);
        try resolved.appendBounded('/');
        try resolved.appendSliceBounded(specifier[cursor_specifier..]);
        return resolved.toOwnedSlice(allocator);
    }
    return specifier;
}

// returns true if the code starting at cursor position matches the pattern
fn peek(code: []const u8, cursor: usize, pattern: []const u8) bool {
    if (cursor + pattern.len > code.len) return false;
    if (std.mem.startsWith(u8, code[cursor..], pattern)) return true;
    return false;
}

// _aa, a1, A1
fn peek_identifier(code: []const u8, cursor: usize) bool {
    // check boundary first
    if (cursor + 1 >= code.len) return false;
    if (std.ascii.isAlphabetic(code[cursor]) or code[cursor] == '_') return true;
    return false;
}

fn consume_identifier(code: []const u8, cursor: *usize) []const u8 {
    const start = cursor.*;
    while (cursor.* < code.len) {
        if (std.ascii.isAlphanumeric(code[cursor.*]) or code[cursor.*] == '_') cursor.* += 1 else break;
    }
    return code[start..cursor.*];
}

// Numetric Literal: 0x1A, 0o1A, 0b1A, 1, 2, 444, 1_000, 1.5
// Boolean Literal: true, false
// String Literal: "aaaxxx", 'hello'
// Null Literal: null
// Undefined Literal: undefined
// Regex Literal: /abc/ig
fn peek_literal(code: []const u8, cursor: usize) bool {
    // boundary check
    if (cursor + 1 > code.len) return false;
    if (std.mem.startsWith(u8, code[cursor..], "0x") or std.mem.startsWith(u8, code[cursor..], "0o") or std.mem.startsWith(u8, code[cursor..], "0b")) {
        // binary literal, octal literal, hexadecimal literal
        return true;
    } else if (std.ascii.isDigit(code[cursor])) {
        // number literal
        return true;
    }
    if (code[cursor] == '"' or code[cursor] == '\'') {
        // string literal
        return true;
    } else if (std.mem.startsWith(u8, code[cursor..], "true") or std.mem.startsWith(u8, code[cursor..], "false")) {
        // boolean literal
        return true;
    } else if (std.mem.startsWith(u8, code[cursor..], "null")) {
        // null literal
        return true;
    } else if (std.mem.startsWith(u8, code[cursor..], "undefined")) {
        // undefined literal
        return true;
    } else if (code[cursor] == '/') {
        // regex literal
        return true;
    }
    return false;
}

fn consume_literal(code: []const u8, cursor: *usize) []const u8 {
    const start = cursor.*;
    if (std.mem.startsWith(u8, code[cursor.*..], "0b")) {
        cursor.* += 2;
        while (cursor.* < code.len) {
            if (code[cursor.*] == '1' or code[cursor.*] == '0') cursor.* += 1 else break;
        }
    } else if (std.mem.startsWith(u8, code[cursor.*..], "0o")) {
        cursor.* += 2;
        while (cursor.* < code.len) {
            switch (code[cursor.*]) {
                '0'...'7' => cursor.* += 1,
                else => break,
            }
        }
    } else if (std.mem.startsWith(u8, code[cursor.*..], "0x")) {
        cursor.* += 2;
        while (cursor.* < code.len) {
            if (std.ascii.isHex(code[cursor.*])) cursor.* += 1 else break;
        }
    } else if (std.ascii.isDigit(code[cursor.*])) {
        while (cursor.* < code.len) {
            if (std.ascii.isDigit(code[cursor.*]) or code[cursor.*] == '_' or code[cursor.*] == '.') cursor.* += 1 else break;
        }
    } else if (code[cursor.*] == '"' or code[cursor.*] == '\'') {
        cursor.* += 1;
        while (cursor.* < code.len) {
            if (code[cursor.*] == '"' or code[cursor.*] == '\'') break else cursor.* += 1;
        }
        cursor.* += 1;
    } else if (std.mem.startsWith(u8, code[cursor.*..], "true")) {
        cursor.* += 4;
    } else if (std.mem.startsWith(u8, code[cursor.*..], "false")) {
        cursor.* += 5;
    } else if (std.mem.startsWith(u8, code[cursor.*..], "null")) {
        cursor.* += 4;
    } else if (std.mem.startsWith(u8, code[cursor.*..], "undefined")) {
        cursor.* += 9;
    } else if (code[cursor.*] == '/') {
        // regex literal
        cursor.* += 1;
        while (cursor.* < code.len) {
            cursor.* += 1;
            if (code[cursor.*] == '/') {
                if (code[cursor.* + 1] == 'i' or code[cursor.* + 1] == 'g' or code[cursor.* + 1] == 'm') {
                    cursor.* += 1;
                    while (cursor.* < code.len) {
                        switch (code[cursor.*]) {
                            'i', 'g', 'm' => cursor.* += 1,
                            else => break,
                        }
                    }
                }
                break;
            }
        }
    }
    return code[start..cursor.*];
}

// strip often refers to removing non-essential characters from the source code before parsing begins
fn strip_whitespace(code: []const u8, cursor: usize) usize {
    var i = cursor;
    while (i < code.len) {
        if (std.ascii.isWhitespace(code[i])) i += 1 else break;
    }
    return i;
}

fn strip_whitespace_comments(code: []const u8, cursor: usize) usize {
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

// pass all code starting at cursor position
// a standalone pass on code that means movement of a cursor from 0 to code.len
fn strip_typescript(allocator: std.mem.Allocator, code: []const u8, cursor: usize) ![]u8 {
    var js_code = try std.ArrayList(u8).initCapacity(allocator, 1024 * 1024);
    var i = cursor;
    while (i < code.len) {
        if (std.ascii.isWhitespace(code[i])) {
            js_code.append(allocator, code[i]) catch unreachable;
            i += 1;
            continue;
        }
        if (peek(code, i, "//")) {
            var cursor_inline_comment = i;
            while (cursor_inline_comment < code.len and code[cursor_inline_comment] != '\n') {
                js_code.append(allocator, code[i]) catch unreachable;
                cursor_inline_comment += 1;
            }
            i = cursor_inline_comment;
            continue;
        }
        if (peek(code, i, "/*")) {
            var cursor_block_comment = i;
            while (cursor_block_comment < code.len and !peek(code, cursor_block_comment, "*/")) {
                js_code.append(allocator, code[cursor_block_comment]) catch unreachable;
                cursor_block_comment += 1;
            }
            i = cursor_block_comment;
            continue;
        }
        // a whole export declaration
        if (peek(code, i, "export")) {
            js_code.appendSlice(allocator, code[i .. i + 6]) catch unreachable;
            i += 6;
            // try Declaration - LexicalDeclaration, such as `export const a: number = 1 as number;`;
            var cursor_lexical_declaration = i;
            while (cursor_lexical_declaration < code.len) {
                if (peek(code, cursor_lexical_declaration, "const") or peek(code, cursor_lexical_declaration, "let")) {
                    if (peek(code, cursor_lexical_declaration, "const")) {
                        js_code.appendSlice(allocator, code[cursor_lexical_declaration .. cursor_lexical_declaration + 5]) catch unreachable;
                        cursor_lexical_declaration += 5;
                    } else {
                        js_code.appendSlice(allocator, code[cursor_lexical_declaration .. cursor_lexical_declaration + 3]) catch unreachable;
                        cursor_lexical_declaration += 3;
                    }
                    // consume one single whitepsace
                    js_code.append(allocator, code[cursor_lexical_declaration]) catch unreachable;
                    cursor_lexical_declaration += 1;
                    // peek at current cursor position for an identifier
                    if (peek_identifier(code, cursor_lexical_declaration)) {
                        js_code.appendSlice(allocator, consume_identifier(code, &cursor_lexical_declaration)) catch unreachable;
                        var cursor_typing = cursor_lexical_declaration;
                        while (cursor_typing < code.len) {
                            if (peek(code, cursor_typing, "=")) {
                                js_code.appendSlice(allocator, "=") catch unreachable;
                                cursor_typing += 1;
                                break;
                            }
                            cursor_typing += 1;
                        }
                        if (cursor_typing == code.len) break;
                        cursor_lexical_declaration = cursor_typing;
                        // consume one single whitespace
                        js_code.append(allocator, code[cursor_lexical_declaration]) catch unreachable;
                        cursor_lexical_declaration += 1;
                        if (peek_literal(code, cursor_lexical_declaration)) {
                            js_code.appendSlice(allocator, consume_literal(code, &cursor_lexical_declaration)) catch unreachable;
                            cursor_typing = cursor_lexical_declaration;
                            while (cursor_typing < code.len) {
                                if (peek(code, cursor_typing, ";")) {
                                    js_code.appendSlice(allocator, ";") catch unreachable;
                                    cursor_typing += 1;
                                    break;
                                }
                                cursor_typing += 1;
                            }
                            cursor_lexical_declaration = cursor_typing;
                        } else {
                            // if cannot peek literal, then consume the rest of the line
                            var cursor_end_of_line = cursor_lexical_declaration;
                            while (cursor_end_of_line < code.len and code[cursor_end_of_line] != '\n') cursor_end_of_line += 1;
                            js_code.appendSlice(allocator, code[cursor_lexical_declaration..cursor_end_of_line]) catch unreachable;
                            cursor_lexical_declaration = cursor_end_of_line;
                        }
                    } else {
                        // if cannot peek identifier, then consume the rest of the line
                        var cursor_end_of_line = cursor_lexical_declaration;
                        while (cursor_end_of_line < code.len and code[cursor_end_of_line] != '\n') cursor_end_of_line += 1;
                        js_code.appendSlice(allocator, code[cursor_lexical_declaration..cursor_end_of_line]) catch unreachable;
                        cursor_lexical_declaration = cursor_end_of_line;
                    }
                    continue;
                }
                js_code.append(allocator, code[cursor_lexical_declaration]) catch unreachable;
                cursor_lexical_declaration += 1;
            }
            i = cursor_lexical_declaration;
            continue;
        }

        js_code.append(allocator, code[i]) catch unreachable;
        i += 1;
    }
    return js_code.toOwnedSlice(allocator);
}

test "module_linkage" {
    const start = std.time.milliTimestamp();
    const dir = try std.fs.cwd().openDir("nativo/src", .{});
    _ = try dir.setAsCwd();
    var entries = [_]Module{Module{ .specifier = "./usecase/main.ts", .parent_path = "./module-linker.zig" }};
    _ = try link_modules(std.testing.allocator, &entries);
    const end = std.time.milliTimestamp();
    std.debug.print("link_modules: {} ms\n", .{end - start});
}

fn print_node(node: *Node) !void {
    std.debug.print("Node module: {s}\n", .{node.module.specifier});
}
fn free_node(node: *Node) !void {
    node.deinit();
}
test "build_module_tree" {
    const dir = try std.fs.cwd().openDir("nativo/src", .{});
    _ = try dir.setAsCwd();
    var module = Module{ .specifier = "./usecase/main.ts", .parent_path = "./module-linker.zig" };
    module.resolved_path = try resolve(std.testing.allocator, module.specifier, module.parent_path);
    module.raw_code = try std.fs.cwd().readFileAlloc(std.testing.allocator, module.resolved_path.?, std.math.maxInt(usize));
    var state = try State.init(std.testing.allocator);
    defer state.deinit();
    var node = try build_module_tree(std.testing.allocator, &state, module);
    try post_order_traverse(&node, print_node);
    defer post_order_traverse(&node, free_node) catch unreachable;
}
