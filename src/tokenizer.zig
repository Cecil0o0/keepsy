//! A rule-based program, performing lexical tokenization, is called tokenizer, or scanner, although scanner is also a term for the first stage of a lexer.
//! It is usually based on a finite-state machine (FSM).
//! For more information: https://en.wikipedia.org/wiki/Finite-state_machine
const std = @import("std");
const evaluate = @import("./evaluator.zig").evaluate;
const EvaluateResult = @import("./evaluator.zig").EvaluateResult;

// Use deterministic finite automata for simply implementing a lexer.
const State = enum {
    // for initial state and the complete state
    NULL,
    // for first match state
    START,
    // for following transitions
    ACCEPTING,
    // when encounters unexpected
    FAILED,
};
pub const SelectDFA = struct {
    state: State = State.NULL,
    value: std.ArrayList(u8) = std.ArrayList(u8).init(std.heap.page_allocator),
    current_ptr_index: u8 = 0,
    col: [2]u32 = [2]u32{ 0, 0 },
    fn transition(self: *SelectDFA, c: u8) !State {
        // state transition table
        switch (self.state) {
            State.NULL => {
                if (c == 's') {
                    self.state = State.START;
                    try self.value.append(c);
                    self.current_ptr_index += 1;
                }
            },
            State.START => {
                if (c == 'e') {
                    self.state = State.ACCEPTING;
                    try self.value.append(c);
                    self.current_ptr_index += 1;
                } else {
                    self.state = State.FAILED;
                    self.current_ptr_index = 0;
                }
            },
            State.ACCEPTING => {
                switch (self.current_ptr_index) {
                    2 => {
                        if (c == 'l') {
                            try self.value.append(c);
                            self.current_ptr_index += 1;
                        } else {
                            self.state = State.FAILED;
                            self.current_ptr_index = 0;
                        }
                    },
                    3 => {
                        if (c == 'e') {
                            try self.value.append(c);
                            self.current_ptr_index += 1;
                        } else {
                            self.state = State.FAILED;
                            self.current_ptr_index = 0;
                        }
                    },
                    4 => {
                        if (c == 'c') {
                            try self.value.append(c);
                            self.current_ptr_index += 1;
                        } else {
                            self.state = State.FAILED;
                            self.current_ptr_index = 0;
                        }
                    },
                    5 => {
                        if (c == 't') {
                            try self.value.append(c);
                            self.state = State.NULL;
                            self.current_ptr_index = 0;
                        } else {
                            self.state = State.FAILED;
                            self.current_ptr_index = 0;
                        }
                    },
                    else => {},
                }
            },
            // when and if the state machine is in the failed state, we will be paniced for current incoming input character.
            State.FAILED => unreachable,
        }
        return self.state;
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
                try self.value.append(c);
                if (c == ',' or c == ' ') {
                    self.state = State.NULL;
                } else {
                    self.state = State.ACCEPTING;
                }
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
pub const OrderByDFA = struct {
    state: State = State.NULL,
    value: [9]u8 = [9]u8{ 'a', 'a', 'a', 'a', 'a', ' ', 'a', 'a', ' ' },
    pointer: u8 = 0,
    col: [2]u32 = [2]u32{ 0, 0 },
    fn transition(self: *OrderByDFA, c: u8) State {
        switch (self.state) {
            State.NULL => {
                if (c == 'o') {
                    self.state = State.START;
                    self.value[self.pointer] = c;
                    self.pointer += 1;
                }
            },
            State.START => {
                if (c == 'r') {
                    self.state = State.ACCEPTING;
                    self.value[self.pointer] = c;
                    self.pointer += 1;
                } else {
                    self.pointer = 0;
                }
            },
            State.ACCEPTING => {
                if ((c == ' ' or c == ';') and self.pointer == 8) {
                    self.state = State.NULL;
                    self.pointer = 0;
                } else {
                    self.value[self.pointer] = c;
                    self.pointer += 1;
                }
            },
            else => {},
        }
        return self.state;
    }
};
pub const OrderByItemDFA = struct {
    state: State = State.NULL,
    value: std.ArrayList(u8) = std.ArrayList(u8).init(std.heap.page_allocator),
    col: [2]u32 = [2]u32{ 0, 0 },
    fn transition(self: *OrderByItemDFA, c: u8) !State {
        switch (self.state) {
            State.NULL => {
                if (c != ' ' and c != ';') {
                    self.state = State.START;
                    try self.value.append(c);
                }
            },
            State.START => {
                if (c == ' ' or c == ';') {
                    self.state = State.NULL;
                } else {
                    self.state = State.ACCEPTING;
                }
                try self.value.append(c);
            },
            State.ACCEPTING => {
                if (c == ' ' or c == ';') {
                    self.state = State.NULL;
                } else {
                    try self.value.append(c);
                }
            },
            else => {},
        }
        return self.state;
    }
};
pub const OrderByDirectionDFA = struct {
    state: State = State.NULL,
    value: [4]u8 = [4]u8{ ' ', ' ', ' ', ' ' },
    pointer: u8 = 0,
    col: [2]u32 = [2]u32{ 0, 0 },
    fn transition(self: *OrderByDirectionDFA, c: u8) State {
        switch (self.state) {
            State.NULL => {
                if (c == 'd' or c == 'a') {
                    self.state = State.START;
                    self.value[self.pointer] = c;
                    self.pointer += 1;
                }
            },
            State.START => {
                self.state = State.ACCEPTING;
                self.value[self.pointer] = c;
                self.pointer += 1;
            },
            State.ACCEPTING => {
                if (c == ' ' or c == ';' or c == '\n') {
                    self.state = State.NULL;
                    self.pointer = 0;
                } else {
                    self.value[self.pointer] = c;
                    self.pointer += 1;
                }
            },
            else => {},
        }
        return self.state;
    }
};
pub const LimitDFA = struct {
    state: State = State.NULL,
    value: std.ArrayList(u8) = std.ArrayList(u8).init(std.heap.page_allocator),
    col: [2]u32 = [2]u32{ 0, 0 },
    fn transition(self: *LimitDFA, c: u8) !State {
        switch (self.state) {
            State.NULL => {
                if (c == 'l') {
                    try self.value.append(c);
                    self.state = State.START;
                }
            },
            State.START => {
                if (c == 'i') {
                    try self.value.append(c);
                    self.state = State.ACCEPTING;
                } else {
                    self.state = State.FAILED;
                }
            },
            State.ACCEPTING => {
                if (c == ';' or c == ' ' or c == '\n') {
                    self.state = State.NULL;
                } else {
                    try self.value.append(c);
                }
            },
            else => {},
        }
        return self.state;
    }
};
pub const NumberDFA = struct {
    state: State = State.NULL,
    value: std.ArrayList(u8) = std.ArrayList(u8).init(std.heap.page_allocator),
    col: [2]u32 = [2]u32{ 0, 0 },
    fn transition(self: *NumberDFA, c: u8) !State {
        switch (self.state) {
            State.NULL => {
                if (c >= 48 and c <= 57) {
                    try self.value.append(c);
                    self.state = State.START;
                }
            },
            State.START => {
                if (c >= 48 and c <= 57) {
                    try self.value.append(c);
                    self.state = State.ACCEPTING;
                } else {
                    self.state = State.FAILED;
                }
            },
            State.ACCEPTING => {
                if (c == ' ' or c == ';' or c == '\n') {
                    self.state = State.NULL;
                }
                if (c >= 48 and c <= 57) {
                    try self.value.append(c);
                }
            },
            State.FAILED => {},
        }
        return self.state;
    }
};
pub const WhereDFA = struct {
    state: State = State.NULL,
    value: std.ArrayList(u8) = std.ArrayList(u8).init(std.heap.page_allocator),
    col: [2]u32 = [2]u32{ 0, 0 },
    fn transition(self: *WhereDFA, c: u8) !State {
        switch (self.state) {
            State.NULL => {
                if (c == 'w') {
                    self.state = State.START;
                    try self.value.append(c);
                }
            },
            State.START => {
                if (c == 'h') {
                    self.state = State.ACCEPTING;
                    try self.value.append(c);
                } else {
                    self.state = State.FAILED;
                }
            },
            State.ACCEPTING => {
                if (c == ' ') {
                    self.state = State.NULL;
                } else {
                    if (c == 'e' or c == 'r') {
                        try self.value.append(c);
                    } else {
                        self.state = State.FAILED;
                    }
                }
            },
            State.FAILED => {},
        }
        return self.state;
    }
};
pub const WhereConditionDFA = struct {
    state: State = State.NULL,
    value: std.ArrayList(u8) = std.ArrayList(u8).init(std.heap.page_allocator),
    col: [2]u32 = [2]u32{ 0, 0 },
    fn transition(self: *WhereConditionDFA, c: u8) !State {
        switch (self.state) {
            State.NULL => {
                if (c != ';') {
                    self.state = State.START;
                    try self.value.append(c);
                }
            },
            State.START, State.ACCEPTING => {
                if (c == ';') {
                    self.state = State.NULL;
                } else {
                    self.state = State.ACCEPTING;
                    try self.value.append(c);
                }
            },
            else => {},
        }
        return self.state;
    }
};
pub const LexemeTag = enum {
    // for zls format with multiple lines when encounters `enum` type
    select,
    from,
    star,
    double_quote_string,
    column,
    table,
    order_by,
    order_by_item,
    order_by_dir,
    limit,
    limit_number,
    where,
    where_condition,
};
pub const Lexeme = union(LexemeTag) {
    // for zls format with multiple lines when encounters `enum` type
    select: SelectDFA,
    from: FromDFA,
    star: StarDFA,
    double_quote_string: DoubleQuoteStringDFA,
    column: ColumnDFA,
    table: TableDFA,
    order_by: OrderByDFA,
    order_by_item: OrderByItemDFA,
    order_by_dir: OrderByDirectionDFA,
    limit: LimitDFA,
    limit_number: NumberDFA,
    where: WhereDFA,
    where_condition: WhereConditionDFA,
};
const TokenizeError = error{ StateFailed, DispatchFailed, IndexedExceedFailed };
const stderr = std.io.getStdErr().writer();
const TokenizeResult = struct { original: []const u8, evaluations: std.ArrayList(EvaluateResult) };

pub fn tokenize(string: []const u8) !TokenizeResult {
    const evaluations = try scan(string);
    return TokenizeResult{ .original = string, .evaluations = evaluations };
}

fn scan(string: []const u8) !std.ArrayList(EvaluateResult) {
    var select_dfa = SelectDFA{};
    // var from_dfa = FromDFA{};
    var star_dfa = StarDFA{};
    var double_quote_dfa = DoubleQuoteStringDFA{};
    var column_dfa = ColumnDFA{};
    // var table_dfa = TableDFA{};
    // var order_by_dfa = OrderByDFA{};
    // var order_by_item_dfa = OrderByItemDFA{};
    // var order_by_dir_dfa = OrderByDirectionDFA{};
    // var limit_dfa = LimitDFA{};
    // var number_dfa = NumberDFA{};
    // var where_dfa = WhereDFA{};
    // var where_condition_dfa = WhereConditionDFA{};
    var token: std.ArrayList(u8) = std.ArrayList(u8).init(std.heap.page_allocator);
    var i: u32 = 0;
    var evaluations = std.ArrayList(EvaluateResult).init(std.heap.page_allocator);
    scan_loop: while (i < string.len) {
        // stripe whitespace
        while (string[i] == ' ' or string[i] == '\n') {
            i += 1;
        }

        std.debug.print("aaaa: {s}\n", .{token.items});
        const c = string[i];
        std.debug.print("\ntry to dispatch letter '{c}' to leading dfa of a statement.", .{c});
        // suspect select token as a candidate
        if (token.items.len == 0 and try select_dfa.transition(c) == State.START) {
            std.debug.print("\nhit select_dfa", .{});
            select_dfa.col[0] = i;
            var j = i + 1;
            while (j + 1 < string.len and try select_dfa.transition(string[j]) == State.ACCEPTING) {
                j += 1;
            }
            // move i pointer
            i = j + 1;
            if (select_dfa.state == State.FAILED) {
                try stderr.print("\ndrop this candidate since it can not be complete in a valid solution: {s}\n", .{select_dfa.value.items});
                return TokenizeError.StateFailed;
            } else {
                select_dfa.col[1] = j;
                std.debug.print("\nselect_dfa accepted: \x1B[32m{s}\x1B[0m", .{select_dfa.value.items});
                try evaluations.append(evaluate(Lexeme{ .select = select_dfa }));
                select_dfa.value.clearAndFree();
                token.clearAndFree();
                try token.appendSlice("select");
            }

            // // suspect `from` segment
            // if (from_dfa.transition(string[i]) == State.START) {
            //     from_dfa.col[0] = i;
            //     var k = i + 1;
            //     while (from_dfa.transition(string[k]) == State.ACCEPTING) {
            //         k += 1;
            //     }
            //     // Generally, if dfa went something wrong such as State.FAILED
            //     if (from_dfa.state == State.FAILED) {
            //         try stderr.print("\nfrom_dfa failed with: {s}\n", .{from_dfa.value});
            //         return TokenizeError.StateFailed;
            //     } else {
            //         from_dfa.col[1] = j;
            //         std.debug.print("\nfrom_dfa   accepted: \x1B[32m{s}\x1B[0m", .{from_dfa.value});
            //         try evaluations.append(evaluate(Lexeme{ .from = from_dfa }));
            //     }
            //     // move i pointer
            //     i = k + 1;
            //     if (i == string.len) break :scan_loop;
            // }

            // // stripe whitespace
            // while (string[i] == ' ' or string[i] == '\n') {
            //     i += 1;
            // }

            // // suspect `table` segment
            // if (try table_dfa.transition(string[i]) == State.START) {
            //     table_dfa.col[0] = i;
            //     var k = i + 1;
            //     while (try table_dfa.transition(string[k]) == State.ACCEPTING) {
            //         if (k + 1 == string.len) {
            //             break;
            //         } else {
            //             k += 1;
            //         }
            //     }
            //     // Generally, if dfa went something wrong such as State.FAILED
            //     if (table_dfa.state == State.FAILED) {
            //         try stderr.print("\ntable_dfa failed with: {s}\n", .{table_dfa.value.items});
            //         return TokenizeError.StateFailed;
            //     } else {
            //         table_dfa.col[1] = k;
            //         std.debug.print("\ntable_dfa  accepted: \x1B[32m{s}\x1B[0m", .{table_dfa.value.items});
            //         try evaluations.append(evaluate(Lexeme{ .table = table_dfa }));
            //     }
            //     // move `i` cursor
            //     i = k + 1;
            //     if (i == string.len) break :scan_loop;
            // }

            // // stripe whitespace
            // while (string[i] == ' ' or string[i] == '\n') {
            //     i += 1;
            // }

            // // suspect `order by` segment
            // if (order_by_dfa.transition(string[i]) == State.START) {
            //     var k = i + 1;
            //     while (order_by_dfa.transition(string[k]) == State.ACCEPTING) {
            //         k += 1;
            //     }
            //     if (order_by_dfa.state == State.FAILED) {
            //         try stderr.print("\norder_by_dfa failed with: {s}\n", .{order_by_dfa.value});
            //         return TokenizeError.StateFailed;
            //     } else {
            //         std.debug.print("\norder_by_dfa accepted: \x1B[32m{s}\x1B[0m", .{order_by_dfa.value});
            //         try evaluations.append(evaluate(Lexeme{ .order_by = order_by_dfa }));
            //     }

            //     // suspect `order by item` segment
            //     if (try order_by_item_dfa.transition(string[k + 1]) == State.START) {
            //         k += 2;
            //         while (try order_by_item_dfa.transition(string[k]) == State.ACCEPTING) {
            //             k += 1;
            //         }
            //         if (order_by_item_dfa.state == State.FAILED) {
            //             try stderr.print("\norder_by_item_dfa failed with: {s}\n", .{order_by_item_dfa.value.items});
            //             return TokenizeError.StateFailed;
            //         } else {
            //             std.debug.print("\norder_by_item_dfa accepted: \x1B[32m{s}\x1B[0m", .{order_by_item_dfa.value.items});
            //             try evaluations.append(evaluate(Lexeme{ .order_by_item = order_by_item_dfa }));
            //             order_by_item_dfa.value.clearAndFree();
            //         }
            //         // move i pointer
            //         i = k + 1;
            //         if (i == string.len) break :scan_loop;

            //         // suspect `order by direction` segment
            //         if (order_by_dir_dfa.transition(string[k + 1]) == State.START) {
            //             k += 2;
            //             while (order_by_dir_dfa.transition(string[k]) == State.ACCEPTING) {
            //                 k += 1;
            //             }
            //             if (order_by_dir_dfa.state == State.FAILED) {
            //                 try stderr.print("\norder_by_dir_dfa failed with: {s}\n", .{order_by_dir_dfa.value});
            //                 return TokenizeError.StateFailed;
            //             } else {
            //                 std.debug.print("\norder_by_dir_dfa accepted: \x1B[32m{s}\x1B[0m", .{order_by_dir_dfa.value});
            //                 try evaluations.append(evaluate(Lexeme{ .order_by_dir = order_by_dir_dfa }));
            //             }
            //             // move i pointer here because nested DFA is done
            //             i = k + 1;
            //             if (i == string.len) break :scan_loop;
            //         }
            //     } else {
            //         try stderr.print("\nindex: {d}, not followed by a item for 'order by'  ", .{k});
            //         return TokenizeError.DispatchFailed;
            //     }
            // }

            // // stripe whitespace
            // while (string[i] == ' ' or string[i] == '\n') {
            //     i += 1;
            // }

            // // suspect `limit` segment
            // if (try limit_dfa.transition(string[i]) == State.START) {
            //     var k = i + 1;
            //     while (try limit_dfa.transition(string[k]) == State.ACCEPTING) {
            //         k += 1;
            //     }
            //     if (limit_dfa.state == State.FAILED) {
            //         try stderr.print("\nlimit_dfa failed with: {s}\n", .{limit_dfa.value.items});
            //         return TokenizeError.StateFailed;
            //     } else {
            //         std.debug.print("\nlimit_dfa accepted: \x1B[32m{s}\x1B[0m", .{limit_dfa.value.items});
            //         try evaluations.append(evaluate(Lexeme{ .limit = limit_dfa }));
            //         limit_dfa.value.clearAndFree();
            //     }
            //     // try followed by number
            //     if (try number_dfa.transition(string[k + 1]) == State.START) {
            //         k += 2;
            //         while (try number_dfa.transition(string[k]) == State.ACCEPTING) {
            //             k += 1;
            //         }
            //         if (number_dfa.state == State.FAILED) {
            //             try stderr.print("\nnumber_dfa failed with: {s}\n", .{number_dfa.value.items});
            //             return TokenizeError.StateFailed;
            //         } else {
            //             std.debug.print("\nnumber_dfa accepted: \x1B[32m{s}\x1B[0m", .{number_dfa.value.items});
            //             try evaluations.append(evaluate(Lexeme{ .limit_number = number_dfa }));
            //             number_dfa.value.clearAndFree();
            //         }
            //         // move i pointer
            //         i = k + 1;
            //         if (i == string.len) break :scan_loop;
            //     }
            // }

            // // stripe whitespace
            // while (string[i] == ' ' or string[i] == '\n') {
            //     i += 1;
            // }

            // // suspect `where` segment
            // if (try where_dfa.transition(string[i]) == State.START) {
            //     var k = i + 1;
            //     while (try where_dfa.transition(string[k]) == State.ACCEPTING) {
            //         k += 1;
            //     }
            //     if (where_dfa.state == State.FAILED) {
            //         try stderr.print("\nwhere_dfa failed with: {s}\n", .{where_dfa.value.items});
            //         return TokenizeError.StateFailed;
            //     } else {
            //         std.debug.print("\nwhere_dfa accepted: \x1B[32m{s}\x1B[0m", .{where_dfa.value.items});
            //         try evaluations.append(evaluate(Lexeme{ .where = where_dfa }));
            //         where_dfa.value.clearAndFree();
            //     }
            //     i = k + 1;
            //     // stripe whitespace
            //     while (string[i] == ' ' or string[i] == '\n') {
            //         i += 1;
            //     }

            //     // try `condition` segement of `where` clause
            //     if (try where_condition_dfa.transition(string[i]) == State.START) {
            //         var condition_k = i + 1;
            //         while (try where_condition_dfa.transition(string[condition_k]) == State.ACCEPTING) {
            //             condition_k += 1;
            //         }
            //         if (where_condition_dfa.state == State.FAILED) {
            //             try stderr.print("\ncondition_dfa failed with: {s}\n", .{where_condition_dfa.value.items});
            //             return TokenizeError.StateFailed;
            //         } else {
            //             std.debug.print("\ncondition_dfa accepted: \x1B[32m{s}\x1B[0m", .{where_condition_dfa.value.items});
            //             try evaluations.append(evaluate(Lexeme{ .where_condition = where_condition_dfa }));
            //             where_condition_dfa.value.clearAndFree();
            //         }
            //         // move i pointer
            //         i = condition_k + 1;
            //         if (i == string.len) break :scan_loop;
            //     }
            // }
        }
        // look backward for `select` to indicate `regular column` identifier
        else if (std.mem.eql(u8, token.items, "select")) {
            // could be extended to `function-call column`.
            if (star_dfa.transition(string[i]) == State.START) {
                // just make dfa complete
                star_dfa.col[0] = i;
                _ = star_dfa.transition('*');
                star_dfa.col[1] = i + 1;
                std.debug.print("\nstar_dfa accepted: \x1B[32m{s}\x1B[0m", .{star_dfa.value});
                try evaluations.append(evaluate(Lexeme{ .star = star_dfa }));
                token.clearAndFree();
                try token.append('*');
                // move i pointer
                i += 1;
                if (i == string.len) break :scan_loop;
            } else {
                // guarantee to access valid memory of a slice
                if (i + 3 >= string.len) break :scan_loop;
                // forward four letter
                while (string[i] != 'f' or string[i + 1] != 'r' or string[i + 2] != 'o' or string[i + 3] != 'm') {
                    if (try column_dfa.transition(string[i]) == State.START) {
                        var k = i + 1;
                        column_dfa.col[0] = k;
                        while (try column_dfa.transition(string[k]) == State.ACCEPTING) {
                            k += 1;
                        }
                        if (column_dfa.state == State.FAILED) {
                            // Generally, if dfa went something wrong such as State.FAILED
                            try stderr.print("\ncolumn_dfa failed with: {s}\n", .{column_dfa.value.items});
                            return TokenizeError.StateFailed;
                        } else {
                            column_dfa.col[1] = k;
                            std.debug.print("\ncolumn_dfa accepted: \x1B[32m{s}\x1B[0m", .{column_dfa.value.items});
                            try evaluations.append(evaluate(Lexeme{ .column = column_dfa }));
                            column_dfa.value.clearAndFree();
                            token.clearAndFree();
                            try token.appendSlice(column_dfa.value.items);
                        }
                        // move i pointer
                        i = k + 1;
                        if (i == string.len) break :scan_loop;
                    }
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
                try evaluations.append(evaluate(Lexeme{ .double_quote_string = double_quote_dfa }));
            }
        } else if (c == ' ') {
            std.debug.print("\nLeading whitespace character will be ignored for now.", .{});
            i += 1;
        } else if (c == ';') {
            std.debug.print("\nEncounter statement terminate character", .{});
            i += 1;
        } else {
            std.debug.print(" This letter don't match any defined dfa", .{});
            i += 1;
        }
    }
    std.debug.print("\n", .{});
    return evaluations;
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
    const string = "select * from user";
    const result = try tokenize(string);
    try std.testing.expectEqualStrings(string, result.original);
}

test "A regular evaluated statement in DQL" {
    const string = "select * from 'user'";
    const result = try tokenize(string);
    std.debug.print("------------ Evaluations as Result below: \n", .{});
    for (result.evaluations.items) |evaluation| {
        std.debug.print("category: {}, value: {s}, indexes from {} to {}\n", .{ evaluation.category, evaluation.value, evaluation.col[0], evaluation.col[1] });
    }
}

test "Two statements in DQL" {
    const string = "select * from \"user\"; select * from \"item\"";
    const result = try tokenize(string);
    try std.testing.expectEqualStrings(string, result.original);
}

test "full example" {
    const string =
        \\ select first_name, last_name, hire_date
        \\ from employees
        \\ order by hire_date desc
        \\ limit 40000
        \\ where hire_date < 1746803432 or Country='Mexico';
    ;
    const result = try tokenize(string);
    try std.testing.expectEqualStrings(string, result.original);
}

test "array overflow" {
    const arr: [3]u8 = .{ 1, 2, 3 };
    arr[4];
}
