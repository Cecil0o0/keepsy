//! This file is designed for implementing an optimal parser for the business of cloud computing.
//! It follows a modular design pattern, so that it could be easy to be embedded into any other projects with different languages in several forms.
//! This module is not tightly coupled with current data engine project, but the precedence and rights are reserved for serving this data engine.
///
/// This module is in the data engine project, and it is responsible for parsing the SQL Text and give an approach for accessing.
/// I will popularize the module with the community, and welcome everyone to contribute into it. The module is firsted crafted by @chenhaojie.chj.
/// This module is motivated by the purpose from chenhaojie.chj for deeply understanding SQL and clarifying the parsing process.
/// Implementing is the only way to do that, so let's get started.
///
/// All I need is to express in zig language to produce the code, and the code will be compiled into executable or library by zig compiler.
/// zig compiler is deeply optimized for building an optimal application program that satisfies my requirement even exceeds my expectation, thus it's a reliable way to walk on.
/// However, the most important reason that I choose zig language is its small and simplicity, which indicates that it could be easily produced and maintained.
const std = @import("std");
/// Because I have the purpose to build a data processing engine, thus I will choose the right language for the data processing.
/// I think the best choice for the data processing is the Structured Query Language (SQL), because it has a deep-rooted presence in everyone's mind.
/// I want every audience could adopt my data engine, thus I choose SQL as the syntax and semantics for expressing and processing data. Other languages are welcome to contribute as well.
const _a_parser_for = "Structured Query Language";
/// name
const _name = "ZQL";
/// The experience of my early implementation of a standalone lexer for ZQL, which let me gain a critical insight with painful feelings:
/// - Far from actual sense, lex is a meaningless procedure for parse ZQL where I spend plenty of time and effort.
/// - Have to do many much lookahead, backtrack and boundary detection just to capture the all lexemes into categories, such as `columns` for identifiers.
/// - have to handle grouping, brackets and parentheses, which make it harder to lex, to make result accurate.
/// - sufferd from ambiguity, hard to distinguish between context-sensitive keywords and identifiers, such as `select order from t`, the `order` is a keyword and also a column name.
/// To reduce the cost of implementation without compromise, I move away from traditional two-phase lexing + parsing, which called `lexerless parser` or `one-pass parser`.
/// For first version, I choose to start with a generic Tree structure to represent the ZQL syntax tree, however it has some drawbacks:
/// Using a generic tree structure would lower performance due to unnecessary complexity and overhead.
/// ZQL is fundamentally a program which is a collection of statements rather than deeply nested hierarchical structures, so a simpler linear representation is more appropriate and efficient.
/// Thus, I decide to start with an intuitive approach `Program` to define the basic struct to contain all the statements.
const Program = struct {
    /// use a generic ArrayList to store the children, which can dynamically grow and shrink as needed for accurate memory usage.
    statements: std.ArrayList(*Statement),
};

/// Data Engine is a performance-sensitive accuracy-critical system, to pursue the best performance and reduce the complexity, I need to carefully design types.
/// I decide to represent all the statements in ZQL with tagged union, tagged union is memory-efficient, it guarantees that only one variant is active at a time.
const Statement = union(enum) {
    SelectStmt: SelectStmt,
    CreateStmt: struct {},
};

const SelectStmt = struct {
    loc: SourceLocation,
    /// I cannot predicate how many `result-column` in a `select-core`, so I need a dynamic-growth array to store them. The `ArrayList` in zig `std` module is an obvious choice.
    columns: std.ArrayList(Column),
    /// It is a specifier that indicates whether the query results should be distinct or not. It is more generic than the distinct keyword on column
    distinct: ?bool = false,
    /// It specifies the table or subquery from which to retrieve the data.
    from_clause: ?*FromClause = null,
    where_clause: ?*WhereClause = null,
    group: ?*struct {} = null,
    window: ?*struct {} = null,
    // Add more fields as needed
};
const Column = struct { loc: SourceLocation, name: []const u8, alias: ?[]const u8, fns: ?[]const u8 };
const FromClause = struct {
    table_or_subquery: std.ArrayList([]const u8),
    join_clause: ?[]const u8,
};
const WhereClause = struct { expr: Expr };

/// Expression is the basic building block of a ZQL query, it represents a value or a computation.
const Expr = struct {
    loc: SourceLocation,
    kind: ExprKind,
};

/// ExprKind is the kind of expression, such as literal
const ExprKind = union(enum) {
    // "ABC" 'a' 123
    LiteralValue: []const u8,
    // like char '?' which means a placeholder for a value to be substituted later
    BindParameter: []const u8,
    // schema-name.table-name.column-name
    // not to design a struct with three slices because of the memory usage.
    // to represent a struct is not necessary, a single slice provides enough information for further processing.
    Identifier: []const u8,
    // negation (prefix), Logical NOT (prefix)
    UnaryOperation: struct {
        operator: []const u8,
        expr: *Expr,
    },
    // addition, subtraction, multiplication, division, modulus, exponentiation
    BinaryOperation: struct {
        operator: []const u8,
        left_hand_side: *Expr,
        right_hand_side: *Expr,
    },
    // function-name ( function-arguments ) -> filter-clause -> over-clause
    FunctionCall: struct {
        name: []const u8,
        arguments: std.ArrayList(*Expr),
        filter: ?*Expr,
        over: ?*Expr,
    },
    // multiple exprs, such as a, b, c -> (a, b, c)
    Tuple: []const Expr,
    // CAST expression AS type
    Cast: struct {
        expr: *Expr,
        type: []const u8,
    },
    Unknown,
    // End of statement, such as ';'
    EndOfStatement,
};

/// SourceLocation is a helpful struct that represents the position of a Statement or Expr or Clause in the text inside a computer program or in an computer file.
/// The information provided by parser, might be used by editor or compiler to report errors or warnings for troubleshooting, debugging, tracking, such as Find All References, Go to Definition, etc.
const SourceLocation = struct {
    /// line and column are both 1-based index, which means the first line and first column are both 1.
    /// if on the 32-bit platform, then the maximum value is 4,294,967,295, which is enough for almost all cases.
    line: usize,
    column: usize,
};

/// The basic functionality of `parse` is to generate a tree from a given SQL Text.
fn parse(allocator: std.mem.Allocator, text: []const u8) !Program {
    // I will treat the text as a string and generate a Text.
    std.debug.print("\n", .{});
    if (text.len == 0) {
        return error.EmptyInput;
    }
    // Before initiated, I need to initialize the Tree, which will be used to store the nodes.
    const nodes = try std.ArrayList(*Statement).initCapacity(allocator, 256);
    var program = Program{ .statements = nodes };
    defer program.statements.deinit(allocator);
    // I will use an `[]const u8` to represent the text
    // Then initialize a cursor to keep track of the current position in the text
    var cursor: usize = 0;
    // fast forward whitespace and comments
    try skipWhitespaceAndComment(text, &cursor);
    // In computer science, a recursive descent parser is a type of top-down parser built from a mutually recursive procedures where each such procedure implements one of the nonterminals of the grammar.
    try parseStatement(allocator, text, &cursor, &program);
    std.debug.print("Statements: {d}\n", .{program.statements.items.len});
    for (program.statements.items) |child| {
        switch (child.*) {
            .SelectStmt => |stmt| {
                for (stmt.columns.items) |column| {
                    std.debug.print("Column: {s}\nLocation: {d}:{d}\nfns: {?s}\nalias: {?s}\n", .{ column.name, column.loc.line, column.loc.column, column.fns, column.alias });
                }
                if (stmt.from_clause) |from| {
                    for (from.table_or_subquery.items) |table_or_subquery| {
                        std.debug.print("Table or Subquery: {s}\n", .{table_or_subquery});
                    }
                }
                if (stmt.where_clause) |where| {
                    std.debug.print("Where: with an expression which ExprKind is `{any}`\n", .{std.meta.activeTag(where.expr.kind)});
                    switch (where.expr.kind) {
                        ExprKind.BinaryOperation => |binary| {
                            std.debug.print("Binary Operation: {s}\n", .{binary.operator});
                            switch (binary.left_hand_side.*.kind) {
                                ExprKind.BinaryOperation => |left_binary| {
                                    std.debug.print("Left Hand Side: {s}\n", .{left_binary.operator});
                                },
                                ExprKind.BindParameter => |bind_parameter| {
                                    std.debug.print("Left Hand Side: {s}\n", .{bind_parameter});
                                },
                                ExprKind.Identifier => |identifier| {
                                    std.debug.print("Left Hand Side: {s}\n", .{identifier});
                                },
                                .Unknown => {
                                    std.debug.print("Left Hand Side: Unknown\n", .{});
                                },
                                else => {},
                            }
                            switch (binary.right_hand_side.*.kind) {
                                ExprKind.BinaryOperation => |right_binary| {
                                    std.debug.print("Right Hand Side: {s}\n", .{right_binary.operator});
                                },
                                ExprKind.BindParameter => |bind_parameter| {
                                    std.debug.print("Right Hand Side: {s}\n", .{bind_parameter});
                                },
                                ExprKind.Identifier => |identifier| {
                                    std.debug.print("Right Hand Side: {s}\n", .{identifier});
                                },
                                .Unknown => {
                                    std.debug.print("Right Hand Side: Unknown\n", .{});
                                },
                                else => {},
                            }
                        },
                        else => {},
                    }
                }
            },
            else => {},
        }
    }
    std.debug.print("\n\nFinished parsing\n", .{});
    return program;
}

// A reusable routine for matching a keyword with a pointer
// it's an implmentation of `lookahead`.
fn matchKeyword(text: []const u8, cursor: usize, keyword: []const u8) bool {
    // Check if the remaining part of the text is long enough for the keyword
    if (cursor + keyword.len > text.len) return false;
    // From the convention, keyword is in uppercase. To obtain a flexible user experience, I will use case-insensitive comparison.
    // That is to say, "SELECT" is equal to "select" and "Select".
    if (!std.ascii.eqlIgnoreCase(text[cursor .. cursor + keyword.len], keyword)) return false;
    // Ensure keyword is not part of a larger identifier
    if (cursor + keyword.len < text.len) {
        const next = text[cursor + keyword.len];
        if ((next >= 'a' and next <= 'z') or
            (next >= 'A' and next <= 'Z') or
            (next >= '0' and next <= '9') or
            next == '_')
        {
            return false; // e.g., "SELECTED" ≠ "SELECT"
        }
    }
    return true;
}

// A reusable routine for looking ahead at the next characters in the text
// this routine don't modify the cursor
fn peek(text: []const u8, cursor: usize, char: []const u8) bool {
    if (cursor + char.len >= text.len) return false;
    return std.mem.eql(u8, text[cursor .. cursor + char.len], char);
}

/// This functionality is for parsing a column in a SELECT statement.
/// the column can be a simple column name, such as "id", or a function call, such as "COUNT(id)".
/// the column identifier can be aliased using the "AS" keyword, such as "id AS user_id".
fn parseColumn(allocator: std.mem.Allocator, text: []const u8, cursor: *usize, columns: *std.ArrayList(Column)) !void {
    try skipWhitespaceAndComment(text, cursor);

    // Parse the column name or function call
    const start = cursor.*;
    var in_parentheses: usize = 0;
    var found_as: bool = false;
    var alias_start: usize = 0;
    var alias_end: usize = 0;

    // Look for the column expression (including potential function calls)
    // Only terminate when we find a comma at the top level (not inside parentheses)
    while (cursor.* < text.len) {
        const c = text[cursor.*];

        if (c == '(') {
            in_parentheses += 1;
        } else if (c == ')') {
            if (in_parentheses > 0) {
                // a stack of parentheses, decrease the counter
                in_parentheses -= 1;
            }
        } else if (in_parentheses == 0 and c == ',') {
            // Found comma at top level, this is the end of the column
            break;
        } else if (in_parentheses == 0 and (c == ' ' or c == '\t' or c == '\n' or c == '\r' or c == ';')) {
            // Check if this is the 'AS' keyword for aliasing
            var temp_cur = cursor.*;
            try skipWhitespaceAndComment(text, &temp_cur);

            // lookahead for 'AS' keyword
            if (temp_cur + 2 < text.len and
                std.ascii.eqlIgnoreCase(text[temp_cur .. temp_cur + 2], "AS"))
            {
                // Verify 'AS' is a complete keyword
                if (temp_cur + 2 >= text.len or
                    !std.ascii.isAlphabetic(text[temp_cur + 2]))
                {
                    found_as = true;
                    cursor.* = temp_cur + 2; // Skip 'AS'
                    try skipWhitespaceAndComment(text, cursor);
                    alias_start = cursor.*;

                    // Find the end of the alias
                    while (cursor.* < text.len) {
                        const alias_c = text[cursor.*];
                        if (alias_c == ',' or alias_c == ' ' or alias_c == '\t' or
                            alias_c == '\n' or alias_c == '\r' or alias_c == ';')
                        {
                            alias_end = cursor.*;
                            break;
                        }
                        cursor.* += 1;
                    }
                    break;
                }
            }
        }
        cursor.* += 1;
    }

    // Extract the column name/expression
    const end = cursor.*;
    if (start >= end) {
        return error.InvalidColumn;
    }

    const column_name = text[start..end];
    var trimmed_column_name = std.mem.trim(u8, column_name, " \t\n\r");

    // Handle alias if found
    var alias: ?[]const u8 = null;
    if (found_as and alias_start < alias_end) {
        alias = try allocator.dupe(u8, std.mem.trim(u8, text[alias_start..alias_end], " \t\n\r"));
    }

    // Determine if this is a function call by checking for parentheses
    var fns: ?[]const u8 = null;
    if (std.mem.indexOf(u8, trimmed_column_name, "(") != null) {
        // Extract function name
        if (std.mem.indexOfScalar(u8, trimmed_column_name, '(')) |paren_pos| {
            fns = try allocator.dupe(u8, std.mem.trim(u8, trimmed_column_name[0..paren_pos], " \t\n\r"));
        }
    }

    // Create and append the column node
    try columns.append(allocator, .{
        .loc = .{ .line = 1, .column = start + 1 }, // Simple location tracking
        .name = try allocator.dupe(u8, trimmed_column_name),
        .alias = alias,
        .fns = fns,
    });
}

fn skipWhitespaceAndComment(text: []const u8, cur: *usize) !void {
    // for loop boundary detection
    while (cur.* < text.len) {
        const c = text[cur.*];
        // for whitespace characters
        if ((c == ' ' or c == '\t' or c == '\n' or c == '\r')) {
            cur.* += 1;
            // for single-line comments
            // quickly look ahead for one character to confirm there have another '-'
            // for pointer boundary detection
        } else if (c == '-' and cur.* + 1 < text.len and text[cur.* + 1] == '-') {
            // move cursor to the next line
            while (cur.* < text.len and text[cur.*] != '\n') {
                cur.* += 1;
            }
            // for multi-line block comments
            // quickly look ahead for one character to confirm there have a following '*'
            // for pointer boundary detection
        } else if (c == '/' and cur.* + 1 < text.len and text[cur.* + 1] == '*') {
            // move cursor to next elements
            cur.* += 2;
            // quickly look ahead for two characters to confirm there have a tailing '*/'
            // for pointer boundary detection
            while (cur.* + 1 < text.len) {
                // terminate detection
                if (text[cur.*] == '*' and text[cur.* + 1] == '/') {
                    cur.* += 2;
                    break;
                } else {
                    cur.* += 1;
                }
            }
            // the responsible for skipping whitespace and comments is done
        } else {
            break;
        }
    }
}

fn parseExpr(allocator: std.mem.Allocator, text: []const u8, cursor: *usize) !Expr {
    try skipWhitespaceAndComment(text, cursor);
    const start = cursor.*;
    if (start >= text.len) return error.OutOfText;
    if (text[start] == ';') {
        cursor.* += 1;
        return Expr{ .loc = .{ .line = 1, .column = start + 1 }, .kind = .EndOfStatement };
    }
    var kind: ExprKind = .Unknown;
    if (text[start] == '"' or text[start] == '\'') {
        while (text[cursor.*] != '"' and text[cursor.*] != '\'') {
            if (text[cursor.*] == '\\') cursor.* += 1;
            cursor.* += 1;
        }
        const end = cursor.*;
        if (end >= text.len) return error.InvalidLiteralValue;
        kind = .{ .LiteralValue = try allocator.dupe(u8, text[start..end]) };
    } else if (text[start] == '?') {
        kind = .{ .BindParameter = try allocator.dupe(u8, text[start..1]) };
    } else if (try parseIdentifier(text, cursor)) |identifier| {
        kind = .{ .Identifier = identifier };
    }
    var left_expr = Expr{ .loc = .{ .line = 1, .column = start + 1 }, .kind = kind };
    var binary_operator_found = false;
    var binary_operator: ?[]const u8 = null;
    var right_expr: ?Expr = null;
    while (cursor.* < text.len) {
        const c = text[cursor.*];
        if (peek(text, cursor.*, "AND")) {
            // binary operator found
            binary_operator_found = true;
            binary_operator = "AND";
            cursor.* += 3;
            right_expr = try parseExpr(allocator, text, cursor);
            break;
        } else if ((c == ';')) {
            // treat ';' as end of statement
            break;
        }
        cursor.* += 1;
    }

    const end = cursor.*;
    if (start > end) {
        return error.InvalidExpression;
    }

    if (binary_operator_found == true) {
        if (std.meta.activeTag(right_expr.?.kind) == .Unknown) {
            return left_expr;
        }
        const binary_expr = Expr{ .loc = .{ .line = 1, .column = end }, .kind = .{ .BinaryOperation = .{ .operator = binary_operator.?, .left_hand_side = &left_expr, .right_hand_side = &right_expr.? } } };
        return binary_expr;
    }

    return Expr{ .loc = .{ .line = 1, .column = end }, .kind = kind };
}

fn parseIdentifier(text: []const u8, cursor: *usize) !?[]const u8 {
    const start = cursor.*;
    const first_char = text[start];
    const is_alphabetic = std.ascii.isAlphabetic(first_char);
    if (first_char != '_' and is_alphabetic == false) return error.InvalidIdentifier;
    var end = start + 1;
    while (end < text.len and (std.ascii.isAlphanumeric(text[end]) or std.ascii.isDigit(text[end]) or text[end] == '_')) {
        end += 1;
    }
    cursor.* = end;
    return text[start..end];
}

// a routine for parsing a `sql-stmt`, refer to https://sqlite.org/syntax/sql-stmt.html
fn parseStatement(allocator: std.mem.Allocator, text: []const u8, cur: *usize, tree: *Program) !void {
    // if it has a leading keyword "SELECT", then it should be indicated as a SELECT statement.
    if (matchKeyword(text, cur.*, "SELECT")) {
        return try parseSelectStatement(text, cur, tree, allocator);
    }

    return error.UnrecognizedStatement;
}

fn parseSelectStatement(text: []const u8, cursor: *usize, tree: *Program, allocator: std.mem.Allocator) !void {
    var node = try allocator.create(Statement);
    node.* = .{
        .SelectStmt = .{
            .loc = .{ .line = 1, .column = 1 },
            // Create a ArrayList with 1024 initial capacity for columns
            .columns = try std.ArrayList(Column).initCapacity(allocator, 1024),
        },
    };
    cursor.* += "SELECT".len;
    // https://sqlite.org/syntax/select-core.html, This LOC of this routine initializes the `select-core` diagram.
    // A loop to parse result-column with comma separator, such as "SELECT a, b, c"
    while (cursor.* < text.len) {
        try skipWhitespaceAndComment(text, cursor);
        try parseColumn(allocator, text, cursor, &node.SelectStmt.columns);
        try skipWhitespaceAndComment(text, cursor);
        // Check for comma separator to terminate the current `result-column` and parse next `result-column`
        if (cursor.* < text.len and text[cursor.*] == ',') {
            cursor.* += 1;
        } else {
            // No more `result-column` to pass
            break;
        }
    }
    try tree.statements.append(allocator, node);

    // Parse FROM clause if present
    try skipWhitespaceAndComment(text, cursor);
    if (matchKeyword(text, cursor.*, "FROM")) {
        cursor.* += "FROM".len;
        try skipWhitespaceAndComment(text, cursor);

        // Parse table name or subquery
        const table_start = cursor.*;
        while (cursor.* < text.len and
            text[cursor.*] != ' ' and
            text[cursor.*] != '\t' and
            text[cursor.*] != '\n' and
            text[cursor.*] != '\r' and
            text[cursor.*] != ';' and
            text[cursor.*] != ',')
        {
            cursor.* += 1;
        }

        if (cursor.* > table_start) {
            var arrayList = try std.ArrayList([]const u8).initCapacity(allocator, 1024);
            try arrayList.append(allocator, text[table_start..cursor.*]);
            switch (node.*) {
                .SelectStmt => |*stmt| {
                    const from_node = try allocator.create(FromClause);
                    from_node.* = .{ .table_or_subquery = arrayList, .join_clause = null };
                    stmt.from_clause = from_node;
                },
                else => {},
            }
        }
    } else {
        return std.debug.print("No FROM clause found.\n", .{});
    }

    try skipWhitespaceAndComment(text, cursor);
    if (matchKeyword(text, cursor.*, "WHERE")) {
        cursor.* += "WHERE".len;
        try skipWhitespaceAndComment(text, cursor);
        const expr = try parseExpr(allocator, text, cursor);
        node.SelectStmt.where_clause = allocator.create(WhereClause) catch |err| {
            std.debug.print("Error creating WhereClause: {any}\n", .{err});
            return err;
        };
        node.SelectStmt.where_clause.?.* = .{ .expr = expr };
    }

    // Found a semicolon, means that I arrived at the end of the `select-stmt`.
    if (cursor.* < text.len and text[cursor.*] == ';') {
        cursor.* += 1;
    }
}

// TODO: Add support for more SQL syntax and features
// reference: https://sqlite.org/syntax.html
// aggregate-function-invocation,alter-table-stmt,analyze-stmt,attach-stmt,begin-stmt,column-constraint,column-def,column-name-list,comment-syntax,commit-stmt,common-table-expression,compound-operator,compound-select-stmt,conflict-clause,create-index-stmt,create-table-stmt,create-trigger-stmt,create-view-stmt,create-virtual-table-stmt,cte-table-name,delete-stmt,delete-stmt-limited,detach-stmt,drop-index-stmt,drop-table-stmt,drop-trigger-stmt,drop-view-stmt,expr,factored-select-stmt,filter-clause,foreign-key-clause,frame-spec,function-arguments,indexed-column,insert-stmt,join-clause,join-constraint,join-operator,literal-value,numeric-literal,ordering-term,over-clause,pragma-stmt,pragma-value,qualified-table-name,raise-function,recursive-cte,reindex-stmt,release-stmt,result-column,returning-clause,rollback-stmt,savepoint-stmt,select-core,select-stmt,signed-number,simple-function-invocation,simple-select-stmt,sql-stmt,sql-stmt-list,table-constraint,table-options,table-or-subquery,type-name,update-stmt,update-stmt-limited,upsert-clause,vacuum-stmt,window-defn,window-function-invocation,with-clause

// reference: https://sqlite.org/syntax/select-core.html
test "select-core" {
    // raw text from QwenChat, an agent which has critical memories with me
    const sample_dql_text =
        \\/* Data Engine Query: Daily Active Users (DAU) Aggregation */
        \\-- Calculate daily active users (DAU) for Q4 2025, excluding test accounts
        \\SELECT
        \\    DATE(event_time) AS event_date,          /* Partition key for downstream */
        \\    COUNT(DISTINCT user_id) AS dau
        \\FROM
        \\    events
        \\WHERE
        \\    event_time >= '2025-10-01'              -- Start of Q4
        \\    AND user_id NOT IN (SELECT id FROM test_users) /* Remove sandbox traffic */
        \\GROUP BY event_date;
    ;
    _ = try parse(std.heap.page_allocator, sample_dql_text);
}
