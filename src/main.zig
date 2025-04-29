const tokenizer = @import("./tokenizer.zig");

pub fn main() !void {
    const string = "select from";

    _ = try tokenizer.tokenize(string);
}
