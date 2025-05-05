//! alias scanner
const std = @import("std");
const evaluate = @import("./evaluator.zig").evaluate;
const EvaluateResult = @import("./evaluator.zig").EvaluateResult;

// reference: https://en.wikipedia.org/wiki/Deterministic_finite_automaton
const State = enum { NULL, START, ACCEPTING, FAILED };
// reference: https://en.wikipedia.org/wiki/Alphabet_(formal_languages)
const alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789()_'\"";
pub const SelectDFA = struct {
    state: State,
    value: [6]u8 = [_]u8{ 1, 1, 1, 1, 1, 1 },
    current_ptr_index: u8 = 0,
    col: [2]u32 = [2]u32{ 0, 0 },
    fn transition(dfa: *SelectDFA, c: u8) State {
        var ptr = &dfa.value;
        switch (dfa.state) {
            State.NULL => {
                if (c == 's') {
                    dfa.state = State.START;
                    ptr[dfa.current_ptr_index] = c;
                    dfa.current_ptr_index += 1;
                }
            },
            State.START => {
                if (c == 'e') {
                    dfa.state = State.ACCEPTING;
                    ptr[dfa.current_ptr_index] = c;
                    dfa.current_ptr_index += 1;
                } else {
                    dfa.state = State.FAILED;
                    dfa.current_ptr_index = 0;
                }
            },
            State.ACCEPTING => {
                switch (dfa.current_ptr_index) {
                    2 => {
                        if (c == 'l') {
                            ptr[dfa.current_ptr_index] = c;
                            dfa.current_ptr_index += 1;
                        } else {
                            dfa.state = State.FAILED;
                            dfa.current_ptr_index = 0;
                        }
                    },
                    3 => {
                        if (c == 'e') {
                            ptr[dfa.current_ptr_index] = c;
                            dfa.current_ptr_index += 1;
                        } else {
                            dfa.state = State.FAILED;
                            dfa.current_ptr_index = 0;
                        }
                    },
                    4 => {
                        if (c == 'c') {
                            ptr[dfa.current_ptr_index] = c;
                            dfa.current_ptr_index += 1;
                        } else {
                            dfa.state = State.FAILED;
                            dfa.current_ptr_index = 0;
                        }
                    },
                    5 => {
                        if (c == 't') {
                            ptr[dfa.current_ptr_index] = c;
                            dfa.state = State.NULL;
                            dfa.current_ptr_index = 0;
                        } else {
                            dfa.state = State.FAILED;
                            dfa.current_ptr_index = 0;
                        }
                    },
                    else => {},
                }
            },
            else => {},
        }
        return dfa.state;
    }
};
pub const StarDFA = struct {
    state: State = State.NULL,
    value: [1]u8 = [1]u8{'*'},
    col: [2]u32 = [2]u32{ 0, 0 },
    fn transition(dfa: *StarDFA, c: u8) State {
        switch (dfa.state) {
            State.NULL => {
                if (c == '*') {
                    dfa.state = State.START;
                }
            },
            else => {
                dfa.state = State.NULL;
            },
        }
        return dfa.state;
    }
};
pub const FromDFA = struct {
    state: State = State.NULL,
    value: [4]u8 = [4]u8{ 0, 0, 0, 0 },
    col: [2]u32 = [2]u32{ 0, 0 },
    fn transition(dfa: *FromDFA, c: u8) State {
        switch (dfa.state) {
            State.NULL => {
                if (c == 'f') {
                    dfa.state = State.START;
                    dfa.value[0] = c;
                }
            },
            State.START => {
                if (c == 'r') {
                    dfa.state = State.ACCEPTING;
                    dfa.value[1] = c;
                } else {
                    dfa.state = State.FAILED;
                }
            },
            State.ACCEPTING => {
                if (c == 'o' and std.mem.eql(u8, dfa.value[0..2], "fr")) {
                    dfa.state = State.ACCEPTING;
                    dfa.value[2] = c;
                } else if (c == 'm' and std.mem.eql(u8, dfa.value[0..3], "fro")) {
                    dfa.state = State.NULL;
                    dfa.value[3] = c;
                } else {
                    dfa.state = State.FAILED;
                }
            },
            else => {},
        }

        return dfa.state;
    }
};
pub const DoubleQuoteStringDFA = struct {
    state: State = State.NULL,
    // given a ArrayList type for a growable list of items in memory, because we don't know how long the string would be!
    value: std.ArrayList(u8) = std.ArrayList(u8).init(std.heap.page_allocator),
    col: [2]u32 = [2]u32{ 0, 0 },
    fn transition(dfa: *DoubleQuoteStringDFA, c: u8) !State {
        switch (dfa.state) {
            State.NULL => {
                if (c == '"') {
                    dfa.state = State.START;
                    dfa.value.clearAndFree();
                    try dfa.value.append(c);
                }
            },
            State.START => {
                dfa.state = State.ACCEPTING;
                try dfa.value.append(c);
            },
            State.ACCEPTING => {
                if (c == '"') {
                    dfa.state = State.NULL;
                }
                try dfa.value.append(c);
            },
            else => {},
        }
        return dfa.state;
    }
};
pub const ColumnDFA = struct {
    state: State = State.NULL,
    value: std.ArrayList(u8) = std.ArrayList(u8).init(std.heap.page_allocator),
    col: [2]u32 = [2]u32{ 0, 0 },
    fn transition(self: *ColumnDFA, c: u8) !State {
        switch (self.state) {
            State.NULL => {
                self.state = State.START;
                try self.value.append(c);
            },
            State.START => {
                self.state = State.ACCEPTING;
                try self.value.append(c);
            },
            State.ACCEPTING => {
                try self.value.append(c);
                if (c == ',' or c == ' ') {
                    self.state = State.NULL;
                }
            },
            else => {
                self.state = State.FAILED;
            },
        }
        return self.state;
    }
};
pub const TableDFA = struct {
    state: State = State.NULL,
    value: std.ArrayList(u8) = std.ArrayList(u8).init(std.heap.page_allocator),
    col: [2]u32 = [2]u32{ 0, 0 },
    fn transition(self: *TableDFA, c: u8) !State {
        switch (self.state) {
            State.NULL => {
                self.state = State.START;
                try self.value.append(c);
            },
            State.START => {
                self.state = State.ACCEPTING;
                try self.value.append(c);
            },
            State.ACCEPTING => {
                try self.value.append(c);
                if (c == ' ' or c == ';') {
                    self.state = State.NULL;
                }
            },
            else => {
                self.state = State.FAILED;
            },
        }
        return self.state;
    }
};
pub const DFATag = enum { select, from, star, double_quote_string, column, table };
pub const DFA = union(DFATag) { select: SelectDFA, from: FromDFA, star: StarDFA, double_quote_string: DoubleQuoteStringDFA, column: ColumnDFA, table: TableDFA };
const TokenizeError = error{StateFailed};
const stderr = std.io.getStdErr().writer();
const TokenizeResult = struct { original: []const u8, evaluations: std.ArrayList(EvaluateResult) };

pub fn tokenize(string: []const u8) !TokenizeResult {
    var select_dfa = SelectDFA{ .state = State.NULL };
    var from_dfa = FromDFA{};
    var star_dfa = StarDFA{};
    var double_quote_dfa = DoubleQuoteStringDFA{};
    var column_dfa = ColumnDFA{};
    var table_dfa = TableDFA{};
    var tokenize_result = TokenizeResult{ .original = string, .evaluations = std.ArrayList(EvaluateResult).init(std.heap.page_allocator) };
    var i: u32 = 0;
    std.debug.print("input string: {s}", .{string});
    while (i < string.len) {
        const c = string[i];
        std.debug.print("\ntry to dispatch dfa '{c}'", .{c});

        // suspect select statement
        if (select_dfa.transition(c) == State.START) {
            std.debug.print("\nhit select_dfa", .{});
            select_dfa.col[0] = i;
            var j = i + 1;
            while (select_dfa.transition(string[j]) == State.ACCEPTING) {
                j += 1;
            }
            // move i cursor
            i = j + 1;
            if (select_dfa.state == State.FAILED) {
                // Generally, if dfa went something wrong such as State.FAILED
                try stderr.print("\nselect_dfa failed with: {s}\n", .{select_dfa.value});
                return TokenizeError.StateFailed;
            } else {
                select_dfa.col[1] = j;
                std.debug.print("\nselect_dfa accepted: \x1B[32m{s}\x1B[0m", .{select_dfa.value});
                try tokenize_result.evaluations.append(evaluate(DFA{ .select = select_dfa }));
            }

            // suspect `regular column` segment, could be extended to `function-call column`.
            if (star_dfa.transition(string[i]) == State.START) {
                // just make dfa complete
                star_dfa.col[0] = i;
                _ = star_dfa.transition(' ');
                i += 1;
                star_dfa.col[1] = i;
                std.debug.print("\nstar_dfa accepted: \x1B[32m{s}\x1B[0m", .{star_dfa.value});
                try tokenize_result.evaluations.append(evaluate(DFA{ .star = star_dfa }));
            } else {
                // forward four letter
                while (string[i] != 'f' or string[i + 1] != 'r' or string[i + 2] != 'o' or string[i + 3] != 'm') {
                    if (try column_dfa.transition(string[i]) == State.START) {
                        var k = i;
                        column_dfa.col[0] = k;
                        while (try column_dfa.transition(string[k]) == State.ACCEPTING) {
                            k += 1;
                        }
                        // move i cursor
                        i = k + 1;
                        if (column_dfa.state == State.FAILED) {
                            // Generally, if dfa went something wrong such as State.FAILED
                            try stderr.print("\ncolumn_dfa failed with: {s}\n", .{column_dfa.value.items});
                            return TokenizeError.StateFailed;
                        } else {
                            column_dfa.col[1] = k;
                            std.debug.print("\ncolumn_dfa accepted: \x1B[32m{s}\x1B[0m", .{column_dfa.value.items});
                            try tokenize_result.evaluations.append(evaluate(DFA{ .column = column_dfa }));
                            column_dfa.value.clearAndFree();
                        }
                    }
                }
            }

            // suspect `from` segment
            if (from_dfa.transition(string[i]) == State.START) {
                std.debug.print("\nhit from_dfa", .{});
                from_dfa.col[0] = i;
                var k = i + 1;
                while (from_dfa.transition(string[k]) == State.ACCEPTING) {
                    k += 1;
                }
                // move i cursor
                i = k + 1;
                // Generally, if dfa went something wrong such as State.FAILED
                if (from_dfa.state == State.FAILED) {
                    try stderr.print("\nfrom_dfa failed with: {s}\n", .{from_dfa.value});
                    return TokenizeError.StateFailed;
                } else {
                    from_dfa.col[1] = j;
                    std.debug.print("\nfrom_dfa accepted: \x1B[32m{s}\x1B[0m", .{from_dfa.value});
                    try tokenize_result.evaluations.append(evaluate(DFA{ .from = from_dfa }));
                }
            }

            // suspect `table` segment
            if (try table_dfa.transition(string[i]) == State.START) {
                table_dfa.col[0] = i;
                var k = i + 1;
                while (try table_dfa.transition(string[k]) == State.ACCEPTING) {
                    k += 1;
                }
                // move `i` cursor
                i = k + 1;
                // Generally, if dfa went something wrong such as State.FAILED
                if (table_dfa.state == State.FAILED) {
                    try stderr.print("\ntable_dfa failed with: {s}\n", .{table_dfa.value.items});
                    return TokenizeError.StateFailed;
                } else {
                    table_dfa.col[1] = k;
                    std.debug.print("\ntable_dfa accepted: \x1B[32m{s}\x1B[0m", .{table_dfa.value.items});
                    try tokenize_result.evaluations.append(evaluate(DFA{ .table = table_dfa }));
                }
            }
        } else if (try double_quote_dfa.transition(c) == State.START) {
            std.debug.print("\nhit double_quote_dfa", .{});
            double_quote_dfa.col[0] = i;
            var j = i + 1;
            while (try double_quote_dfa.transition(string[j]) == State.ACCEPTING) {
                j += 1;
            }
            i = j + 1;
            // Generally, if dfa went something wrong such as State.FAILED
            if (double_quote_dfa.state == State.FAILED) {
                try stderr.print("\ndouble_quote_dfa failed with: {s}\n", .{double_quote_dfa.value.items});
                return TokenizeError.StateFailed;
            } else {
                double_quote_dfa.col[1] = j;
                std.debug.print("\ndouble_quote_dfa accepted: \x1B[32m{s}\x1B[0m", .{double_quote_dfa.value.items});
                try tokenize_result.evaluations.append(evaluate(DFA{ .double_quote_string = double_quote_dfa }));
            }
        } else if (c == ' ') {
            std.debug.print(" Leading whitespace character will be ignored for now.", .{});
            i += 1;
        } else {
            std.debug.print(" This letter don't match any defined dfa", .{});
            i += 1;
        }
    }
    std.debug.print("\n", .{});
    return tokenize_result;
}

test "A incorrect keyword in DQL" {
    const string = "serect";
    try std.testing.expectError(TokenizeError.StateFailed, tokenize(string));
}

test "A correct keyword/identifier in DQL" {
    const string = "select * from";
    const result = try tokenize(string);
    try std.testing.expectEqualStrings(string, result.original);
}

test "A regular statement in DQL" {
    const string = "select * from \"user\"";
    const result = try tokenize(string);
    try std.testing.expectEqualStrings(string, result.original);
}

test "A regular statement in DQL with evaluation" {
    const string = "select * from \"user\"";
    const result = try tokenize(string);
    std.debug.print("------------ Evaluations as Result below: \n", .{});
    for (result.evaluations.items) |evaluation| {
        std.debug.print("category: {}, value: {c}, index_from_to: [{}, {}]\n", .{ evaluation.category, evaluation.value, evaluation.col[0], evaluation.col[1] });
    }
}

test "Two statements in DQL" {
    const string = "select * from \"user\"; select * from \"tradement\"";
    const result = try tokenize(string);
    try std.testing.expectEqualStrings(string, result.original);
}

test "full example" {
    const string =
        \\ select first_name, last_name, hire_date
        \\ from employees;
    ;
    const result = try tokenize(string);
    try std.testing.expectEqualStrings(string, result.original);
}
