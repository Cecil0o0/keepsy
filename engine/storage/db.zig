const std = @import("std");
const c = @cImport({
    @cInclude("sqlite3.h");
});

pub fn callback(_: ?*anyopaque, column_count: c_int, column_value: [*c][*c]u8, column_name: [*c][*c]u8) callconv(.c) c_int {
    for (0..@intCast(column_count)) |i| {
        if (column_value[i] != null) {
            // std.debug.print("{s} = {s}\n", .{ column_name[i], column_value[i] });
        } else {
            std.debug.print("{s} = NULL\n", .{column_name[i]});
        }
    }
    return 0;
}

fn exec_sql_string(db: ?*c.sqlite3, sql: [*c]const u8) !void {
    var err_msg: [*c]u8 = undefined;
    const exec_result = c.sqlite3_exec(db, sql, &callback, null, &err_msg);
    switch (exec_result) {
        c.SQLITE_OK => {
            // std.debug.print("Execute Success!\n", .{});
        },
        c.SQLITE_ERROR => {
            std.debug.print("error: {s}\n", .{err_msg});
            return error.ExecError;
        },
        else => unreachable,
    }
}

pub fn main() !void {
    var db: ?*c.sqlite3 = undefined;
    const open_result = c.sqlite3_open("database.db", &db);
    defer _ = c.sqlite3_close(db);

    if (open_result != c.SQLITE_OK) {
        std.debug.print("error: {s}\n", .{c.sqlite3_errmsg(db)});
        return error.OpenError;
    }

    const ddl =
        \\ CREATE TABLE IF NOT EXISTS tb1 (
        \\     id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\     name TEXT NOT NULL
        \\ );
    ;
    const dml =
        \\ INSERT INTO tb1 (name) VALUES ('hello');
    ;
    try exec_sql_string(db, ddl);
    var timer = try std.time.Timer.start();
    const quantity = 100_000;
    for (0..quantity) |_| {
        try exec_sql_string(db, dml);
    }
    std.debug.print("Insert {d} record with Time Elapsed: {d} ms\n", .{ quantity, timer.read() / 1000 / 1000 });
    var timer_for_reader = try std.time.Timer.start();
    try exec_sql_string(db, "SELECT * FROM tb1;");
    std.debug.print("Read whole table with Time Elapsed: {d} ms\n", .{timer_for_reader.read() / 1000 / 1000});
}
