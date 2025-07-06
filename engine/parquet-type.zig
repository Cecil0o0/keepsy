//! reference: https://github.com/apache/parquet-format/blob/master/LogicalTypes.md
pub const Schema = struct {};
pub const RowGroup = struct {};
pub const KeyValue = struct {};
pub const ColumnOrder = struct {};

// reference: https://parquet.apache.org/docs/file-format/metadata/
pub const FileMetaData = struct {
    version: i32,
    schema: []Schema,
    num_rows: i64,
    row_groups: []RowGroup,
    key_value_metadata: []KeyValue,
    created_by: []const u8,
    column_orders: []ColumnOrder,
    encryption_algorithm: comptime_int,
    footer_signing_key_metadata: []const u8
};
