const std = @import("std");
const DFATag = @import("./tokenizer.zig").DFATag;
const DFA = @import("./tokenizer.zig").DFA;
const SelectDFA = @import("./tokenizer.zig").SelectDFA;
const FromDFA = @import("./tokenizer.zig").FromDFA;
const ColumnDFA = @import("./tokenizer.zig").ColumnDFA;
const TableDFA = @import("./tokenizer.zig").TableDFA;
const OrderByDFA = @import("./tokenizer.zig").OrderByDFA;
const OrderByItemDFA = @import("./tokenizer.zig").OrderByItemDFA;
const LexicalCategory = enum {
    // Names assigned by the programmer
    identifier,
    // Reserved words of the language
    keyword,
    // Punctuation characters and paired delimiters
    punctuator,
    // Symbols that operate on arguments and produce results
    operator,
    // Numeric, logical, textual, and reference discarded.
    literal,
    // Line of block comments. Usually discarded
    comment,
    // Groups of non-printable characters. Usually discarded
    whitespace,
};

pub const EvaluateResult = struct {
    category: LexicalCategory,
    value: []const u8,
    col: [2]u32,
};

pub fn evaluate(dfa: DFA) EvaluateResult {
    switch (dfa) {
        DFATag.select => {
            return EvaluateResult{ .category = LexicalCategory.keyword, .value = dfa.select.value[0..], .col = dfa.select.col };
        },
        DFATag.from => {
            return EvaluateResult{ .category = LexicalCategory.keyword, .value = dfa.from.value[0..], .col = dfa.from.col };
        },
        DFATag.star => {
            return EvaluateResult{ .category = LexicalCategory.punctuator, .value = dfa.star.value[0..], .col = dfa.star.col };
        },
        DFATag.double_quote_string => {
            return EvaluateResult{ .category = LexicalCategory.literal, .value = dfa.double_quote_string.value.items, .col = dfa.double_quote_string.col };
        },
        DFATag.column => {
            return EvaluateResult{ .category = LexicalCategory.identifier, .value = dfa.column.value.items, .col = dfa.column.col };
        },
        DFATag.table => {
            return EvaluateResult{ .category = LexicalCategory.identifier, .value = dfa.table.value.items, .col = dfa.table.col };
        },
        DFATag.order_by => {
            return EvaluateResult{ .category = LexicalCategory.keyword, .value = dfa.order_by.value[0..], .col = dfa.order_by.col };
        },
        DFATag.order_by_item => {
            return EvaluateResult{ .category = LexicalCategory.identifier, .value = dfa.order_by_item.value.items, .col = dfa.order_by_item.col };
        },
    }
}
