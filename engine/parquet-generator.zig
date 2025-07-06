//! A generator implementation for Apache Parquet, an open source, column-oriented data file format designed for efficient data storage and retrieval.
//!
//! See [Apache Parquet](https://parquet.apache.org/) for more information.

const std = @import("std");
const FileMetaData = @import("./parquet-type.zig").FileMetaData;
const Schema = @import("./parquet-type.zig").Schema;
const RowGroup = @import("./parquet-type.zig").RowGroup;
const KeyValue = @import("./parquet-type.zig").KeyValue;
const ColumnOrder = @import("./parquet-type.zig").ColumnOrder;

// reference: https://parquet.apache.org/docs/file-format/
pub fn writeFile() !void {
    const file = try std.fs.cwd().createFile("out/generated_by_zig.parquet", std.fs.File.CreateFlags{ .mode = 0o666 });
    defer file.close();
    const writer = file.writer();

    try writer.writeAll("PAR1"); // Magic string at start of file.

    // Write column chunk
    const start_pos = try file.getPos();
    try writer.writeInt(i32, 42, .little);
    const end_pos = try file.getPos();
    std.debug.print("{} {}\n", .{ start_pos, end_pos });

    // Write row groups

    // File metadata is written after the data to allow for single-pass writing.
    const metadata = FileMetaData{
        .version = 1,
        .created_by = "Keepsy Zig MVP",
        .num_rows = 2,
        .encryption_algorithm = 0,
        .footer_signing_key_metadata = "12",
        .schema = &[_]Schema{},
        .row_groups = &[_]RowGroup{},
        .key_value_metadata = &[_]KeyValue{},
        .column_orders = &[_]ColumnOrder{}
    };
    try writer.writeInt(i32, metadata.version, .little); // Write version.

    try writer.writeAll("PAR1"); // magic string paired at end of file.
}
