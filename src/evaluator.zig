const std = @import("std");
const LexemTag = @import("./tokenizer.zig").LexemTag;
const Lexem = @import("./tokenizer.zig").Lexem;
const SelectDFA = @import("./tokenizer.zig").SelectDFA;
const FromDFA = @import("./tokenizer.zig").FromDFA;
const ColumnDFA = @import("./tokenizer.zig").ColumnDFA;
const TableDFA = @import("./tokenizer.zig").TableDFA;
const OrderByDFA = @import("./tokenizer.zig").OrderByDFA;
const OrderByItemDFA = @import("./tokenizer.zig").OrderByItemDFA;
const OrderByDirectionDFA = @import("./tokenizer.zig").OrderByDirectionDFA;
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

pub fn evaluate(lexem: Lexem) EvaluateResult {
    switch (lexem) {
        LexemTag.select => {
            return EvaluateResult{ .category = LexicalCategory.keyword, .value = lexem.select.value[0..], .col = lexem.select.col };
        },
        LexemTag.from => {
            return EvaluateResult{ .category = LexicalCategory.keyword, .value = lexem.from.value[0..], .col = lexem.from.col };
        },
        LexemTag.star => {
            return EvaluateResult{ .category = LexicalCategory.identifier, .value = lexem.star.value[0..], .col = lexem.star.col };
        },
        LexemTag.double_quote_string => {
            return EvaluateResult{ .category = LexicalCategory.literal, .value = lexem.double_quote_string.value.items, .col = lexem.double_quote_string.col };
        },
        LexemTag.column => {
            return EvaluateResult{ .category = LexicalCategory.identifier, .value = lexem.column.value.items, .col = lexem.column.col };
        },
        LexemTag.table => {
            return EvaluateResult{ .category = LexicalCategory.identifier, .value = lexem.table.value.items, .col = lexem.table.col };
        },
        LexemTag.order_by => {
            return EvaluateResult{ .category = LexicalCategory.keyword, .value = lexem.order_by.value[0..], .col = lexem.order_by.col };
        },
        LexemTag.order_by_item => {
            return EvaluateResult{ .category = LexicalCategory.identifier, .value = lexem.order_by_item.value.items, .col = lexem.order_by_item.col };
        },
        LexemTag.order_by_dir => {
            return EvaluateResult{ .category = LexicalCategory.keyword, .value = lexem.order_by_dir.value[0..], .col = lexem.order_by_dir.col };
        },
        LexemTag.limit => {
            return EvaluateResult{ .category = LexicalCategory.keyword, .value = lexem.limit.value.items, .col = lexem.limit.col };
        },
        LexemTag.limit_number => {
            return EvaluateResult{ .category = LexicalCategory.literal, .value = lexem.limit_number.value.items, .col = lexem.limit_number.col };
        },
        LexemTag.where => {
            return EvaluateResult{ .category = LexicalCategory.keyword, .value = lexem.where.value.items, .col = lexem.where.col };
        },
    }
}
