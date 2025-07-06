const std = @import("std");
const LexemeTag = @import("./tokenizer.zig").LexemeTag;
const Lexeme = @import("./tokenizer.zig").Lexeme;
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

pub fn evaluate(lexem: Lexeme) EvaluateResult {
    switch (lexem) {
        LexemeTag.select => {
            return EvaluateResult{ .category = LexicalCategory.keyword, .value = "select", .col = lexem.select.col };
        },
        LexemeTag.from => {
            return EvaluateResult{ .category = LexicalCategory.keyword, .value = "from", .col = lexem.from.col };
        },
        LexemeTag.star => {
            return EvaluateResult{ .category = LexicalCategory.keyword, .value = "*", .col = lexem.star.col };
        },
        LexemeTag.double_quote_string => {
            return EvaluateResult{ .category = LexicalCategory.literal, .value = lexem.double_quote_string.value.items, .col = lexem.double_quote_string.col };
        },
        LexemeTag.column => {
            var copy = std.ArrayList(u8).init(std.heap.page_allocator);
            copy.appendSlice(lexem.column.value.items[0..]) catch unreachable;
            return EvaluateResult{ .category = LexicalCategory.identifier, .value = copy.items, .col = lexem.column.col };
        },
        LexemeTag.table => {
            var copy = std.ArrayList(u8).init(std.heap.page_allocator);
            copy.appendSlice(lexem.table.value.items[0..]) catch unreachable;
            return EvaluateResult{ .category = LexicalCategory.identifier, .value = copy.items, .col = lexem.table.col };
        },
        LexemeTag.order_by => {
            return EvaluateResult{ .category = LexicalCategory.keyword, .value = "order by", .col = lexem.order_by.col };
        },
        LexemeTag.order_by_item => {
            var copy = std.ArrayList(u8).init(std.heap.page_allocator);
            copy.appendSlice(lexem.order_by_item.value.items[0..]) catch unreachable;
            return EvaluateResult{ .category = LexicalCategory.identifier, .value = copy.items, .col = lexem.order_by_item.col };
        },
        LexemeTag.order_by_dir => {
            var copy = std.ArrayList(u8).init(std.heap.page_allocator);
            copy.appendSlice(lexem.order_by_dir.value[0..]) catch unreachable;
            return EvaluateResult{ .category = LexicalCategory.keyword, .value = copy.items, .col = lexem.order_by_dir.col };
        },
        LexemeTag.limit => {
            return EvaluateResult{ .category = LexicalCategory.keyword, .value = "limit", .col = lexem.limit.col };
        },
        LexemeTag.limit_number => {
            var copy = std.ArrayList(u8).init(std.heap.page_allocator);
            copy.appendSlice(lexem.limit_number.value.items[0..]) catch unreachable;
            return EvaluateResult{ .category = LexicalCategory.literal, .value = copy.items, .col = lexem.limit_number.col };
        },
        LexemeTag.where => {
            return EvaluateResult{ .category = LexicalCategory.keyword, .value = "where", .col = lexem.where.col };
        },
        LexemeTag.where_condition => {
            var copy = std.ArrayList(u8).init(std.heap.page_allocator);
            copy.appendSlice(lexem.where_condition.value.items[0..]) catch unreachable;
            return EvaluateResult{ .category = LexicalCategory.literal, .value = copy.items, .col = lexem.where_condition.col };
        },
        LexemeTag.with => {
            return EvaluateResult{ .category = LexicalCategory.keyword, .value = lexem.with.value.items, .col = lexem.with.col };
        },
        LexemeTag.temporary_table => {
            return EvaluateResult{ .category = LexicalCategory.literal, .value = lexem.temporary_table.value.items, .col = lexem.temporary_table.col };
        },
        LexemeTag.left_parenthesis => {
            return EvaluateResult{ .category = LexicalCategory.punctuator, .value = "(", .col = lexem.left_parenthesis.col };
        },
        LexemeTag.right_parenthesis => {
            return EvaluateResult{ .category = LexicalCategory.punctuator, .value = ")", .col = lexem.right_parenthesis.col };
        },
        LexemeTag.as => {
            return EvaluateResult{ .category = LexicalCategory.keyword, .value = "as", .col = lexem.as.col };
        },
    }
}
