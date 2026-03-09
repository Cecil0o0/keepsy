/// This module is responsible for linking modules which contains code.
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

    fn init(allocator: std.mem.Allocator, module: Module) !Node {
        return Node{
            .childLeftNodes = try std.ArrayList(Node).initCapacity(allocator, 1024),
            .childRightNodes = try std.ArrayList(Node).initCapacity(allocator, 1024),
            .module = module,
            .allocator = allocator,
        };
    }

    fn deinit(self: *Node) void {
        self.childLeftNodes.deinit(self.allocator);
        self.childRightNodes.deinit(self.allocator);
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
pub fn linkModules(allocator: std.mem.Allocator, entries: *[1]Module) !void {
    var state = try State.init(allocator);
    defer state.deinit();

    for (entries) |module| {
        var buf: [1024]u8 = undefined;
        var buf_parent: [1024]u8 = undefined;
        const path = try resolve(&buf, module.specifier, try std.fs.realpath(module.parent_path, &buf_parent));
        const code = try std.fs.cwd().readFileAlloc(state.allocator, path, std.math.maxInt(usize));
        defer state.allocator.free(code);

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
                    cursor = stripWhitespace(code, cursor);
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
                    cursor_NamedImports = stripWhitespace(NamedImports.items, cursor_NamedImports);
                    while (cursor_NamedImports < NamedImports.items.len) {
                        if (peekIdentifier(NamedImports.items, cursor_NamedImports)) {
                            const ModuleExportName = consumeIdentifier(NamedImports.items, &cursor_NamedImports);
                            const ModuleExportNameCopy = try state.allocator.dupe(u8, ModuleExportName);
                            cursor_NamedImports = stripWhitespace(NamedImports.items, cursor_NamedImports);
                            if (peek(NamedImports.items, cursor_NamedImports, "as")) {
                                cursor_NamedImports += 2;
                                cursor_NamedImports = stripWhitespace(NamedImports.items, cursor_NamedImports);
                                // cosume an identifier
                                const ImportedBinding = consumeIdentifier(NamedImports.items, &cursor_NamedImports);
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
                            cursor_NamedImports = stripWhitespace(NamedImports.items, cursor_NamedImports);
                            if (peek(code, cursor_NamedImports, ",")) {
                                cursor_NamedImports += 1;
                                cursor_NamedImports = stripWhitespace(NamedImports.items, cursor_NamedImports);
                                continue;
                            }
                        }
                        cursor_NamedImports += 1;
                    }

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
                                var buf_path_to_file: [1024]u8 = undefined;
                                const path_to_file = try resolve(&buf_path_to_file, ModuleSpecifier.items, path);
                                const module_code = try std.fs.cwd().readFileAlloc(state.allocator, path_to_file, std.math.maxInt(usize));
                                defer allocator.free(module_code);
                                // parse ExportDeclaration
                                // parse Declaration
                                // parse HoistableDeclaration
                                // parse FunctionDeclaration
                                // reference: https://tc39.es/ecma262/#prod-ExportSpecifier
                                var module_cursor: usize = 0;
                                module_cursor = stripWhitespaceAndComments(module_code, module_cursor);

                                while (module_cursor < module_code.len) {
                                    if (peek(module_code, module_cursor, "export")) {
                                        module_cursor += 6;
                                        module_cursor = stripWhitespaceAndComments(module_code, module_cursor);

                                        if (peek(module_code, module_cursor, "function")) {
                                            module_cursor += 8;
                                            module_cursor = stripWhitespaceAndComments(module_code, module_cursor);

                                            // consume function name
                                            const func_name = consumeIdentifier(module_code, &module_cursor);
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
                                try state.output.appendSlice(state.allocator, module_code);
                            }
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

        // write binding code by exported FunctionDeclaration
        var iter = state.symbol_table.iterator();
        while (iter.next()) |entry| {
            std.debug.print("   🔗🔗🔗 {s} ({s}) from {s}\n", .{ entry.key_ptr.*, entry.value_ptr.@"[[LinkKind]]", entry.value_ptr.@"[[ImportedBindingValue]]" });
            if (std.mem.eql(u8, entry.value_ptr.@"[[LinkKind]]", "ImportedBinding")) {
                try state.output.appendSlice(state.allocator, "\n// Define an immutable ImportedBinding here");
                try state.output.appendSlice(state.allocator, "\nconst ");
                try state.output.appendSlice(state.allocator, entry.key_ptr.*);
                try state.output.appendSlice(state.allocator, " = ");
                try state.output.appendSlice(state.allocator, entry.value_ptr.@"[[ImportedBindingValue]]");
                try state.output.appendSlice(state.allocator, ";\n");
            }
        }

        try state.output.appendSlice(state.allocator, code[end_of_linking_cursor..]);
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

fn buildModuleTree(allocator: std.mem.Allocator, module: Module) !Node {
    var node = try Node.init(allocator, module);
    const code = module.raw_code.?;

    var cursor: usize = 0;
    while (cursor < code.len) {
        cursor = stripWhitespaceAndComments(code, cursor);
        if (peek(code, cursor, "import")) {
            cursor += 6;
            cursor = stripWhitespace(code, cursor);
            // Althrough there is no need for now to consume the `ImportClause` cause I just want to find the `from` keyword for `FromClause`.
            // but I should consume it to make the syntax correct
            while (cursor < code.len) {
                cursor += 1;
                if (peek(code, cursor, "from")) break;
            }
            if (peek(code, cursor, "from")) {
                cursor += 4;
                cursor = stripWhitespace(code, cursor);
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
                try node.childLeftNodes.append(allocator, try buildModuleTree(allocator, Module{
                    .specifier = dependency_module_specifier,
                    .parent_path = module.resolved_path.?,
                }));
            }
        } else {
            // peek and pass the `ImportDeclaration`, or else I will break the while loop
            break;
        }
    }
    return node;
}

fn postOrderTraverse(node: *Node, visit: fn (node: *Node) void) void {
    for (0..node.childLeftNodes.items.len) |i| {
        postOrderTraverse(&node.childLeftNodes.items[i], visit);
    }
    for (0..node.childRightNodes.items.len) |i| {
        postOrderTraverse(&node.childRightNodes.items[i], visit);
    }
    visit(node);
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

// returns true if the code starting at cursor position matches the pattern
fn peek(code: []const u8, cursor: usize, pattern: []const u8) bool {
    if (cursor + pattern.len > code.len) return false;
    if (std.mem.startsWith(u8, code[cursor..], pattern)) return true;
    return false;
}

// _aa, a1, A1
fn peekIdentifier(code: []const u8, cursor: usize) bool {
    if (cursor + 1 > code.len) return false;
    if (std.ascii.isAlphabetic(code[cursor]) or code[cursor] == '_') return true;
    return false;
}

fn consumeIdentifier(code: []const u8, cursor: *usize) []const u8 {
    const start = cursor.*;
    while (cursor.* < code.len) {
        if (std.ascii.isAlphanumeric(code[cursor.*]) or code[cursor.*] == '_') cursor.* += 1 else break;
    }
    return code[start..cursor.*];
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

test "module_linkage" {
    var entries = [_]Module{Module{ .specifier = "./usecase/main.ts", .parent_path = "./module-linker.zig" }};
    _ = try linkModules(std.testing.allocator, &entries);
}

fn printNode(node: *Node) void {
    std.debug.print("Node module: {s}\n", .{node.module.specifier});
}
fn freeNode(node: *Node) void {
    node.deinit();
}
test "module_linkage_tree" {
    var module = Module{ .specifier = "./usecase/main.ts", .parent_path = "./module-linker.zig" };
    var buf: [1024]u8 = undefined;
    module.resolved_path = try resolve(&buf, module.specifier, module.parent_path);
    module.raw_code = try std.fs.cwd().readFileAlloc(std.testing.allocator, module.resolved_path.?, std.math.maxInt(usize));
    var node = try buildModuleTree(std.testing.allocator, module);
    postOrderTraverse(&node, printNode);
    defer postOrderTraverse(&node, freeNode);
}
