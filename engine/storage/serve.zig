const std = @import("std");
const c = @cImport({
    @cInclude("sqlite3.h");
});

const ServeError = error{
    // occur when no permission to access file
    OpenFileError,
    // occurs more frequently than event of other events.
    InterpretError,
    // not occur in expect
    InterpretElseError };

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var db: ?*c.sqlite3 = undefined;
    const open_result = c.sqlite3_open("system.db", &db);
    defer _ = c.sqlite3_close(db);

    if (open_result != c.SQLITE_OK) {
        std.debug.print("Error open file: {s}\n", .{c.sqlite3_errmsg(db)});
        return error.OpenFileError;
    }

    var Address = try std.net.Address.parseIp4("0.0.0.0", 8000);
    var server = try Address.listen(.{ .reuse_address = true });
    defer server.deinit();

    std.debug.print("Listening on port: 8000\n", .{});

    while (true) {
        try handle_connection(allocator, try server.accept(), db);
    }
}

fn handle_connection(allocator: std.mem.Allocator, conn: std.net.Server.Connection, db: ?*c.sqlite3) !void {
    defer conn.stream.close();
    var buffer_for_incoming_bytes: [1024]u8 = undefined;
    var http_server = std.http.Server.init(conn, &buffer_for_incoming_bytes);
    var req = try http_server.receiveHead();

    const path = req.head.target;
    std.debug.print("\npath: {s}", .{req.head.target});

    if (std.mem.eql(u8, path, "/")) {
        var html_buffer: [10240]u8 = undefined;
        const html_content = try std.fs.cwd().readFile("ui.html", &html_buffer);
        try req.respond(html_content, .{ .status = .ok, .extra_headers = &.{.{
            .name = "Content-Type",
            .value = "text/html",
        }} });
    } else if (std.mem.eql(u8, path, "/interpret")) {
        var reader = try req.reader();
        const body = try reader.readAllAlloc(allocator, 1024);
        defer allocator.free(body);
        std.debug.print("\nincoming body (len: {d}), bytes followed: \n{s}", .{ body.len, body });
        const result = try interpret(allocator, body, db);
        try req.respond(result, .{ .extra_headers = &.{.{
            .name = "Content-Type",
            .value = "text/csv",
        }} });
    } else if (std.mem.eql(u8, path, "/explore")) {
        const result = try std.process.Child.run(.{ .allocator = allocator, .argv = &.{ "sqlite3", "system.db", ".tables" } });
        if (result.term.Exited > 0) {
            return try req.respond(result.stderr, .{});
        }
        return try req.respond(result.stdout, .{});
    }
}

fn interpret(allocator: std.mem.Allocator, sql: []u8, db: ?*c.sqlite3) ![]u8 {
    var csv = std.ArrayList(u8).init(allocator);
    defer csv.deinit();

    var context = CallbackContextForCSVFormat{
        .allocator = allocator,
        .writer = csv.writer(),
        .has_csv_header = false,
    };

    var err_msg: [*c]u8 = undefined;
    // [Sqlite3 reference](https://sqlite.org/c3ref/exec.html)
    const exec_result = c.sqlite3_exec(db, sql.ptr, &interpret_callback, &context, &err_msg);

    switch (exec_result) {
        c.SQLITE_OK => {
            if (csv.items.len > 1024 * 1024) {
                std.debug.print("\nToo to print to terminal, the length is {d}.", .{csv.items.len});
            } else {
                std.debug.print("\nInterpret Success: \n{s}", .{csv.items});
            }
        },
        c.SQLITE_ERROR => {
            std.debug.print("\nInterpret Error: {s}", .{err_msg});
            return error.InterpretError;
        },
        else => {
            std.debug.print("\nInterpret Error: {s}", .{err_msg});
            return error.InterpretElseError;
        },
    }

    return csv.toOwnedSlice();
}

fn interpret_callback(context: ?*anyopaque, column_count: c_int, column_value: [*c][*c]u8, column_name: [*c][*c]u8) callconv(.C) c_int {
    if (context) |context_ptr| {
        var callback_context_for_csv_format = @as(*CallbackContextForCSVFormat, @ptrCast(@alignCast(context_ptr)));
        if (callback_context_for_csv_format.has_csv_header == false) {
            for (0..@intCast(column_count)) |i| {
                callback_context_for_csv_format.writer.print("{s},", .{column_name[i]}) catch return 1;
            }
            callback_context_for_csv_format.writer.print("\n", .{}) catch return 1;
            callback_context_for_csv_format.has_csv_header = true;
        }
        for (0..@intCast(column_count)) |i| {
            callback_context_for_csv_format.writer.print("{s},", .{column_value[i]}) catch return 1;
        }
        callback_context_for_csv_format.writer.print("\n", .{}) catch return 1;
    }
    return 0;
}

const CallbackContextForCSVFormat = struct { allocator: std.mem.Allocator, writer: std.ArrayList(u8).Writer, has_csv_header: bool };
