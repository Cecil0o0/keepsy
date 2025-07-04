//! A rule-based program, performing lexical tokenization, is called tokenizer, or scanner, although scanner is also a term for the first stage of a lexer.
//! It is usually based on a finite-state machine (FSM).
//! For more information: https://en.wikipedia.org/wiki/Finite-state_machine
const std = @import("std");
const evaluate = @import("./evaluator.zig").evaluate;
const EvaluateResult = @import("./evaluator.zig").EvaluateResult;

/// Use deterministic finite automata for simply implementing a lexer.
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
            State.FAILED => {},
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
pub const BareStringDFA = struct {
    state: State = State.NULL,
    value: std.ArrayList(u8) = std.ArrayList(u8).init(std.heap.page_allocator),
    col: [2]u32 = [2]u32{ 0, 0 },
    fn transition(self: *BareStringDFA, c: u8) !State {
        switch (self.state) {
            State.NULL => {
                if (std.ascii.isAlphanumeric(c)) {
                    self.state = State.START;
                    try self.value.append(c);
                }
            },
            State.START => {
                if (c == ' ') {
                    self.state = State.NULL;
                } else if (std.ascii.isAlphanumeric(c)) {
                    try self.value.append(c);
                    self.state = State.ACCEPTING;
                } else {
                    self.state = State.FAILED;
                }
            },
            State.ACCEPTING => {
                if (c == ' ') {
                    self.state = State.NULL;
                } else if (std.ascii.isAlphanumeric(c)) {
                    try self.value.append(c);
                } else {
                    self.state = State.FAILED;
                }
            },
            else => {},
        }
        return self.state;
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
                if (c == ' ') {} else if (c == ',') {
                    self.state = State.NULL;
                } else {
                    self.state = State.ACCEPTING;
                    try self.value.append(c);
                }
            },
            State.ACCEPTING => {
                if (c == ' ') {} else if (c == ',' or c == '\n' or c == ')') {
                    self.state = State.NULL;
                } else {
                    try self.value.append(c);
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
                if (c == ' ') {} else if (c == ';' or c == '\n' or c == ')') {
                    self.state = State.NULL;
                } else {
                    try self.value.append(c);
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
pub const WithDFA = struct {
    state: State = State.NULL,
    value: std.ArrayList(u8) = std.ArrayList(u8).init(std.heap.page_allocator),
    col: [2]u32 = [2]u32{ 0, 0 },
    fn transition(self: *WithDFA, c: u8) !State {
        switch (self.state) {
            State.NULL => {
                if (c == 'w') {
                    self.state = State.START;
                    try self.value.append(c);
                }
            },
            State.START => {
                if (c == 'i') {
                    self.state = State.ACCEPTING;
                    try self.value.append(c);
                } else {
                    self.state = State.FAILED;
                }
            },
            State.ACCEPTING => {
                if (c == ' ' or c == ';' or c == '\n') {
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
pub const AsDFA = struct {
    state: State = State.NULL,
    value: std.ArrayList(u8) = std.ArrayList(u8).init(std.heap.page_allocator),
    col: [2]u32 = [2]u32{ 0, 0 },
    fn transition(self: *AsDFA, c: u8) !State {
        switch (self.state) {
            State.NULL => {
                if (c == 'a') {
                    self.state = State.START;
                    try self.value.append(c);
                }
            },
            State.START => {
                if (c == 's') {
                    self.state = State.NULL;
                    try self.value.append(c);
                } else {
                    self.state = State.FAILED;
                }
            },
            else => unreachable,
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
    with,
    temporary_table,
    left_parenthesis,
    right_parenthesis,
    as,
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
    with: WithDFA,
    temporary_table: BareStringDFA,
    left_parenthesis: BareStringDFA,
    right_parenthesis: BareStringDFA,
    as: AsDFA,
};
const TokenizeError = error{DFAStateFailed};
const stderr = std.debug;
pub const TokenizeResult = struct { original: []const u8, evaluations: std.ArrayList(EvaluateResult) };

pub fn tokenize(string: []const u8) !TokenizeResult {
    const evaluations = try scan(string);
    return TokenizeResult{ .original = string, .evaluations = evaluations };
}

fn scan(string: []const u8) !std.ArrayList(EvaluateResult) {
    var select_dfa = SelectDFA{};
    var from_dfa = FromDFA{};
    var star_dfa = StarDFA{};
    var double_quote_dfa = DoubleQuoteStringDFA{};
    var column_dfa = ColumnDFA{};
    var table_dfa = TableDFA{};
    var order_by_dfa = OrderByDFA{};
    var order_by_item_dfa = OrderByItemDFA{};
    var order_by_dir_dfa = OrderByDirectionDFA{};
    var limit_dfa = LimitDFA{};
    var number_dfa = NumberDFA{};
    var where_dfa = WhereDFA{};
    var where_condition_dfa = WhereConditionDFA{};
    var with_dfa = WithDFA{};
    var bare_string_dfa = BareStringDFA{};
    var as_dfa = AsDFA{};
    var token: std.ArrayList(u8) = std.ArrayList(u8).init(std.heap.page_allocator);
    var lexeme_tag: LexemeTag = undefined;
    var i: u32 = 0;
    var evaluations = std.ArrayList(EvaluateResult).init(std.heap.page_allocator);
    scan_loop: while (i < string.len) {
        // strip whitespace and newlines
        while (string[i] == ' ' or string[i] == '\n') i += 1;

        const c = string[i];
        if (token.items.len == 0 and try with_dfa.transition(c) == State.START) {
            with_dfa.col[0] = i;
            var j = i + 1;
            while (j + 1 < string.len and try with_dfa.transition(string[j]) == State.ACCEPTING) {
                j += 1;
            }
            i = j + 1;
            if (with_dfa.state == State.FAILED) {
                stderr.print("\nUnexpected token: {s}\n", .{with_dfa.value.items});
                return TokenizeError.DFAStateFailed;
            } else {
                with_dfa.col[1] = j;
                std.debug.print("\nwith_dfa accepted: \x1B[32m{s}\x1B[0m", .{with_dfa.value.items});

                try evaluations.append(evaluate(Lexeme{ .with = with_dfa }));
                if (try bare_string_dfa.transition(string[with_dfa.col[1] + 1]) == State.START) {
                    var k = with_dfa.col[1] + 2;
                    while (k + 1 < string.len and try bare_string_dfa.transition(string[k]) == State.ACCEPTING) k += 1;
                    // move i pointer
                    if (bare_string_dfa.state == State.FAILED) {
                        stderr.print("\nUnexpected token: {s}\n", .{bare_string_dfa.value.items});
                        return TokenizeError.DFAStateFailed;
                    } else {
                        i = k + 1;
                        bare_string_dfa.col[1] = k;
                        std.debug.print("\nbare_string_dfa accepted: \x1B[32m{s}\x1B[0m", .{bare_string_dfa.value.items});
                        try evaluations.append(evaluate(Lexeme{ .temporary_table = bare_string_dfa }));

                        // strip whitespace
                        while (string[i] == ' ') i += 1;

                        if (string[i] == '(') {
                            var m = i + 1;
                            while (string[m] != ')') {
                                while (string[m] == ' ') m += 1;
                                if (try column_dfa.transition(string[m]) == State.START) {
                                    column_dfa.col[0] = m;
                                    m += 1;
                                    while (try column_dfa.transition(string[m]) == State.ACCEPTING) m += 1;
                                    if (column_dfa.state == State.FAILED) return TokenizeError.DFAStateFailed;
                                    column_dfa.col[1] = m;
                                    std.debug.print("\ncolumn_dfa accepted: \x1B[32m{s}\x1B[0m", .{column_dfa.value.items});
                                    try evaluations.append(evaluate(.{ .column = column_dfa }));
                                    column_dfa.value.clearAndFree();
                                }
                                if (string[m] == ',') {
                                    m += 1;
                                    continue;
                                }
                            }
                            i = m + 1;
                        }

                        // strip whitespace
                        while (string[i] == ' ') i += 1;

                        if (try as_dfa.transition(string[i]) == State.START) {
                            var l = i + 1;
                            while (try as_dfa.transition(string[l]) == State.ACCEPTING) {
                                l += 1;
                            }
                            i = l + 1;
                            if (as_dfa.state == State.FAILED) {
                                return error.StateFailed;
                            } else {
                                try evaluations.append(evaluate(.{ .as = as_dfa }));
                                token.clearAndFree();
                                try token.appendSlice(as_dfa.value.items);
                            }
                        } else {
                            return error.InvalidToken;
                        }
                    }
                }
            }
        }
        // suspect select token as a candidate
        else if (try select_dfa.transition(c) == State.START) {
            select_dfa.col[0] = i;
            var j = i + 1;
            while (j + 1 < string.len and try select_dfa.transition(string[j]) == State.ACCEPTING) {
                j += 1;
            }
            // move i pointer
            i = j + 1;
            if (select_dfa.state == State.FAILED) {
                stderr.print("\ndrop this candidate since it can not be complete in a valid solution: {s}\n", .{select_dfa.value.items});
                return TokenizeError.DFAStateFailed;
            } else {
                select_dfa.col[1] = j;
                std.debug.print("\nselect_dfa accepted: \x1B[32m{s}\x1B[0m", .{select_dfa.value.items});
                try evaluations.append(evaluate(Lexeme{ .select = select_dfa }));
                select_dfa.value.clearAndFree();
                token.clearAndFree();
                try token.appendSlice("select");
            }
        }
        // look backward one token for `select` to indicate `regular column` identifier
        else if (std.mem.eql(u8, token.items, "select")) {
            // could be extended to `function-call column`.
            if (star_dfa.transition(string[i]) == State.START) {
                // just make dfa complete
                star_dfa.col[0] = i;
                _ = star_dfa.transition('*');
                star_dfa.col[1] = i;
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
                // forward for `from`
                while (!std.mem.eql(u8, string[i .. i + 4], "from")) {
                    if (try column_dfa.transition(string[i]) == State.START) {
                        var k = i + 1;
                        column_dfa.col[0] = k;
                        while (try column_dfa.transition(string[k]) == State.ACCEPTING) {
                            k += 1;
                        }
                        if (column_dfa.state == State.FAILED) {
                            // Generally, if dfa went something wrong such as State.FAILED
                            stderr.print("\ncolumn_dfa failed with: {s}\n", .{column_dfa.value.items});
                            return TokenizeError.DFAStateFailed;
                        } else {
                            column_dfa.col[1] = k;
                            std.debug.print("\ncolumn_dfa accepted: \x1B[32m{s}\x1B[0m", .{column_dfa.value.items});
                            try evaluations.append(evaluate(Lexeme{ .column = column_dfa }));
                            token.clearAndFree();
                            try token.appendSlice(column_dfa.value.items);
                            column_dfa.value.clearAndFree();
                        }
                        // move i pointer
                        i = k + 1;
                        if (i == string.len) break :scan_loop;
                        // strip whitespace
                        while (string[i] == ' ' or string[i] == '\n') {
                            i += 1;
                        }
                    }
                }
            }
        }
        // look backward one token for `from` to indicate `table` identifier
        else if (std.mem.eql(u8, token.items, "from") and try table_dfa.transition(string[i]) == State.START) {
            table_dfa.col[0] = i;
            var k = i + 1;
            while (try table_dfa.transition(string[k]) == State.ACCEPTING) k += 1;
            // Generally, if dfa went something wrong such as State.FAILED
            if (table_dfa.state == State.FAILED) {
                stderr.print("\ntable_dfa failed with: {s}\n", .{table_dfa.value.items});
                return TokenizeError.DFAStateFailed;
            } else {
                table_dfa.col[1] = k;
                std.debug.print("\ntable_dfa  accepted: \x1B[32m{s}\x1B[0m", .{table_dfa.value.items});
                try evaluations.append(evaluate(Lexeme{ .table = table_dfa }));
                table_dfa.value.clearAndFree();
                token.clearAndFree();
                try token.appendSlice(table_dfa.value.items);
            }
            // move `i` pointer
            i = k;
            if (i == string.len) break :scan_loop;
        }
        // `from` token
        else if (from_dfa.transition(string[i]) == State.START) {
            from_dfa.col[0] = i;
            var k = i + 1;
            while (from_dfa.transition(string[k]) == State.ACCEPTING) {
                k += 1;
            }
            // Generally, if dfa went something wrong such as State.FAILED
            if (from_dfa.state == State.FAILED) {
                stderr.print("\nfrom_dfa failed with: {s}\n", .{from_dfa.value});
                return TokenizeError.DFAStateFailed;
            } else {
                from_dfa.col[1] = k;
                std.debug.print("\nfrom_dfa   accepted: \x1B[32m{s}\x1B[0m", .{from_dfa.value});
                try evaluations.append(evaluate(Lexeme{ .from = from_dfa }));
                token.clearAndFree();
                try token.appendSlice("from");
            }
            // move i pointer
            i = k + 1;
            if (i == string.len) break :scan_loop;
        }
        // looking backward one token for `where` to indicate `where_condition` token
        else if (std.mem.eql(u8, token.items, "where") and try where_condition_dfa.transition(string[i]) == State.START) {
            var condition_k = i + 1;
            where_condition_dfa.col[0] = i;
            while (try where_condition_dfa.transition(string[condition_k]) == State.ACCEPTING) {
                condition_k += 1;
            }
            if (where_condition_dfa.state == State.FAILED) {
                stderr.print("\ncondition_dfa failed with: {s}\n", .{where_condition_dfa.value.items});
                return TokenizeError.DFAStateFailed;
            } else {
                where_condition_dfa.col[1] = condition_k;
                std.debug.print("\ncondition_dfa accepted: \x1B[32m{s}\x1B[0m", .{where_condition_dfa.value.items});
                try evaluations.append(evaluate(Lexeme{ .where_condition = where_condition_dfa }));
                where_condition_dfa.value.clearAndFree();
            }
            // move i pointer
            i = condition_k + 1;
            if (i == string.len) break :scan_loop;
        }
        // `where` token
        else if (try where_dfa.transition(c) == State.START) {
            var k = i + 1;
            where_dfa.col[0] = i;
            while (try where_dfa.transition(string[k]) == State.ACCEPTING) {
                k += 1;
            }
            if (where_dfa.state == State.FAILED) {
                stderr.print("\nwhere_dfa failed with: {s}\n", .{where_dfa.value.items});
                return TokenizeError.DFAStateFailed;
            }
            where_dfa.col[1] = k;
            std.debug.print("\nwhere_dfa accepted: \x1B[32m{s}\x1B[0m", .{where_dfa.value.items});
            try evaluations.append(evaluate(Lexeme{ .where = where_dfa }));

            token.clearAndFree();
            try token.appendSlice("where");

            where_dfa.value.clearAndFree();
            i = k;
        }
        // looking backward one token for `LexemeTag.order_by_item` to indicate `order_by_dir`
        else if (lexeme_tag == LexemeTag.order_by_item and order_by_dir_dfa.transition(c) == State.START) {
            var k = i + 1;
            order_by_dir_dfa.col[0] = i;
            while (order_by_dir_dfa.transition(string[k]) == State.ACCEPTING) k += 1;
            if (order_by_dir_dfa.state == State.FAILED) {
                stderr.print("\norder_by_dir_dfa failed with: {s}\n", .{order_by_dir_dfa.value});
                return TokenizeError.DFAStateFailed;
            }
            order_by_dir_dfa.col[1] = k;
            std.debug.print("\norder_by_dir_dfa accepted: \x1B[32m{s}\x1B[0m", .{order_by_dir_dfa.value});
            try evaluations.append(evaluate(Lexeme{ .order_by_dir = order_by_dir_dfa }));
            token.clearAndFree();
            try token.appendSlice(order_by_dir_dfa.value[0..]);
            lexeme_tag = LexemeTag.order_by_dir;
            // move i pointer here because nested DFA is done
            i = k;
            if (i == string.len) break :scan_loop;
        }
        // looking backward one token for `order by` to indicate `order_by_item` token
        else if (std.mem.eql(u8, token.items, "order by") and try order_by_item_dfa.transition(string[i]) == State.START) {
            var k = i + 1;
            order_by_item_dfa.col[0] = i;
            while (try order_by_item_dfa.transition(string[k]) == State.ACCEPTING) {
                k += 1;
            }
            if (order_by_item_dfa.state == State.FAILED) {
                stderr.print("\norder_by_item_dfa failed with: {s}\n", .{order_by_item_dfa.value.items});
                return TokenizeError.DFAStateFailed;
            } else {
                order_by_item_dfa.col[1] = k;
                std.debug.print("\norder_by_item_dfa accepted: \x1B[32m{s}\x1B[0m", .{order_by_item_dfa.value.items});
                try evaluations.append(evaluate(Lexeme{ .order_by_item = order_by_item_dfa }));
                token.clearAndFree();
                try token.appendSlice(order_by_item_dfa.value.items);
                lexeme_tag = LexemeTag.order_by_item;
                order_by_item_dfa.value.clearAndFree();
            }
            // move i pointer
            i = k + 1;
            if (i == string.len) break :scan_loop;
        }
        // `order by` token
        else if (order_by_dfa.transition(c) == State.START) {
            var k = i + 1;
            order_by_dfa.col[0] = i;
            while (order_by_dfa.transition(string[k]) == State.ACCEPTING) {
                k += 1;
            }
            if (order_by_dfa.state == State.FAILED) {
                stderr.print("\norder_by_dfa failed with: {s}\n", .{order_by_dfa.value});
                return TokenizeError.DFAStateFailed;
            } else {
                order_by_dfa.col[1] = k;
                std.debug.print("\norder_by_dfa accepted: \x1B[32m{s}\x1B[0m", .{order_by_dfa.value});
                try evaluations.append(evaluate(Lexeme{ .order_by = order_by_dfa }));
                token.clearAndFree();
                try token.appendSlice("order by");
            }
            i = k + 1;
            if (i == string.len) break :scan_loop;
        }
        // looking backward one token for `limit` to indicate `limit_number` token
        else if (std.mem.eql(u8, token.items, "limit") and try number_dfa.transition(c) == State.START) {
            var k = i + 1;
            number_dfa.col[0] = i;
            while (try number_dfa.transition(string[k]) == State.ACCEPTING) {
                k += 1;
            }
            if (number_dfa.state == State.FAILED) {
                stderr.print("\nnumber_dfa failed with: {s}\n", .{number_dfa.value.items});
                return TokenizeError.DFAStateFailed;
            } else {
                number_dfa.col[1] = k;
                std.debug.print("\nnumber_dfa accepted: \x1B[32m{s}\x1B[0m", .{number_dfa.value.items});
                try evaluations.append(evaluate(Lexeme{ .limit_number = number_dfa }));
                token.clearAndFree();
                try token.appendSlice(number_dfa.value.items);
                number_dfa.value.clearAndFree();
            }
            // move i pointer
            i = k + 1;
            if (i == string.len) break :scan_loop;
        }
        // `limit` token
        else if (try limit_dfa.transition(c) == State.START) {
            var k = i + 1;
            limit_dfa.col[0] = i;
            while (try limit_dfa.transition(string[k]) == State.ACCEPTING) {
                k += 1;
            }
            if (limit_dfa.state == State.FAILED) {
                stderr.print("\nlimit_dfa failed with: {s}\n", .{limit_dfa.value.items});
                return TokenizeError.DFAStateFailed;
            } else {
                limit_dfa.col[1] = k;
                std.debug.print("\nlimit_dfa accepted: \x1B[32m{s}\x1B[0m", .{limit_dfa.value.items});
                try evaluations.append(evaluate(Lexeme{ .limit = limit_dfa }));
                token.clearAndFree();
                try token.appendSlice("limit");
                limit_dfa.value.clearAndFree();
            }
            // move i pointer
            i = k + 1;
            if (i == string.len) break :scan_loop;
        }
        // `double_quote_string_literal` token
        else if (try double_quote_dfa.transition(c) == State.START) {
            std.debug.print("\nhit double_quote_dfa", .{});
            double_quote_dfa.col[0] = i;
            var j = i + 1;
            while (try double_quote_dfa.transition(string[j]) == State.ACCEPTING) {
                j += 1;
            }
            i = j + 1;
            if (double_quote_dfa.state == State.FAILED) {
                unreachable;
            } else {
                double_quote_dfa.col[1] = j;
                std.debug.print("\ndouble_quote_dfa accepted: \x1B[32m{s}\x1B[0m", .{double_quote_dfa.value.items});
                try evaluations.append(evaluate(Lexeme{ .double_quote_string = double_quote_dfa }));
            }
        } else if (c == '(') {
            std.debug.print("\nleft_parenthesis accepted: \x1B[32m{c}\x1B[0m", .{'('});
            try evaluations.append(evaluate(Lexeme{ .left_parenthesis = BareStringDFA{ .col = [2]u32{ i, i } } }));
            token.clearAndFree();
            try token.append('(');
            lexeme_tag = LexemeTag.left_parenthesis;
            i += 1;
        } else if (c == ')') {
            std.debug.print("\nright_parenthesis accepted: \x1B[32m{c}\x1B[0m", .{')'});
            try evaluations.append(evaluate(Lexeme{ .right_parenthesis = BareStringDFA{ .col = [2]u32{ i, i } } }));
            token.clearAndFree();
            try token.append(')');
            lexeme_tag = LexemeTag.right_parenthesis;
            i += 1;
        } else if (c == ' ') {
            std.debug.print("\nLeading whitespace character will be ignored for now.", .{});
            i += 1;
        } else if (c == ';') {
            std.debug.print("\nEncounter statement terminate character: \x1B[32m{c}\x1B[0m", .{';'});
            i += 1;
        } else {
            std.debug.print("\nThis letter '{c}' don't match any defined dfa", .{c});
            i += 1;
        }
    }
    std.debug.print("\n", .{});
    return evaluations;
}

test "A incorrect keyword in DQL" {
    const string = "serect";
    try std.testing.expectError(TokenizeError.DFAStateFailed, tokenize(string));
}

test "A correct keyword/identifier in DQL" {
    const string = "select * from";
    const result = try tokenize(string);
    try std.testing.expectEqualStrings(string, result.original);
}

test "A regular statement in DQL" {
    const string = "select * from user;";
    const result = try tokenize(string);
    try std.testing.expectEqualStrings(string, result.original);
}

test "A regular evaluated statement in DQL" {
    const string = "select * from user;";
    const result = try tokenize(string);
    std.debug.print("------------ Evaluations as Result below: \n", .{});
    for (result.evaluations.items) |evaluation| {
        std.debug.print("category: {}, value: {s}, len: {d}, indexed from {} to {} \n", .{ evaluation.category, evaluation.value, evaluation.value.len, evaluation.col[0], evaluation.col[1] });
    }
}

test "Two statements in DQL" {
    const string = "select * from \"user\"; select * from \"item\";";
    const result = try tokenize(string);
    try std.testing.expectEqualStrings(string, result.original);
}

test "select-stmt" {
    const string =
        \\ select first_name, last_name, hire_date
        \\ from employees
        \\ order by hire_date desc
        \\ limit 40000
        \\ where hire_date < 1746803432 or Country='Mexico';
    ;
    const result = try tokenize(string);
    try std.testing.expectEqualStrings(string, result.original);
    std.debug.print("------------ Evaluations as Result below: \n", .{});
    for (result.evaluations.items) |evaluation| {
        std.debug.print("category: {}, value: {s}, len: {d}, indexed from {} to {} \n", .{ evaluation.category, evaluation.value, evaluation.value.len, evaluation.col[0], evaluation.col[1] });
    }
}

test "with-clause" {
    const string = "with temporaryTable as ( select avg(salary) from employee );";
    const result = try tokenize(string);
    try std.testing.expectEqualStrings(string, result.original);
    std.debug.print("------------ Evaluations as Result below: \n", .{});
    for (result.evaluations.items) |evaluation| {
        std.debug.print("category: {}, value: {s}, len: {d}, indexed from {} to {} \n", .{ evaluation.category, evaluation.value, evaluation.value.len, evaluation.col[0], evaluation.col[1] });
    }
}

test "common-table-expression" {
    const string = "with tableName (column1, column2) as (select * from tableName1);";
    _ = try tokenize(string);
}

test "window-defn" {}
