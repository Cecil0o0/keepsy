const tokenizer = @import("./tokenizer.zig");
const generator = @import("./parquet-generator.zig");

pub fn main() !void {
    // const string = "select from";

    // _ = try tokenizer.tokenize(string);

    try generator.writeFile();
}
