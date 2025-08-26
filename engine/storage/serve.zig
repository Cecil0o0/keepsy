const std = @import("std");
const c = @cImport({
    @cInclude("sqlite3.h");
});

const CallbackContext = struct {
    writer: std.ArrayList(u8).Writer,
    allocator: std.mem.Allocator,
};

pub fn callback(callback_ptr: ?*anyopaque, column_count: c_int, column_value: [*c][*c]u8, column_name: [*c][*c]u8) callconv(.c) c_int {
    if (callback_ptr) |context_ptr| {
        const context: *CallbackContext = @ptrCast(@alignCast(context_ptr));
        for (0..@intCast(column_count)) |i| {
            if (column_value[i] != null) {
                _ = context.writer.print("{s} = {s}\n", .{ column_name[i], column_value[i] }) catch return 1;
            } else {
                std.debug.print("{s} = NULL\n", .{column_name[i]});
            }
        }
    }

    return 0;
}

fn exec_sql_string(allocator: std.mem.Allocator, db: ?*c.sqlite3, sql: [*c]const u8) ![]u8 {
    var csv = std.ArrayList(u8).init(allocator);
    errdefer csv.deinit();

    var context = CallbackContext{
        .writer = csv.writer(),
        .allocator = allocator,
    };

    var err_msg: [*c]u8 = undefined;
    // reference: https://sqlite.org/c3ref/exec.html
    const exec_result = c.sqlite3_exec(db, sql, &callback, &context, &err_msg);
    switch (exec_result) {
        c.SQLITE_OK => {
            std.debug.print("\nExecute Success!", .{});
        },
        c.SQLITE_ERROR => {
            std.debug.print("\nerror: {s}", .{err_msg});
        },
        else => unreachable,
    }
    return csv.items;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var db: ?*c.sqlite3 = undefined;
    const open_result = c.sqlite3_open("database.db", &db);
    defer _ = c.sqlite3_close(db);

    if (open_result != c.SQLITE_OK) {
        std.debug.print("error: {s}\n", .{c.sqlite3_errmsg(db)});
        return error.OpenError;
    }

    const ip = "30.221.100.136";
    const address = try std.net.Address.parseIp4(ip, 8000);
    var server = try address.listen(.{});
    defer server.deinit();

    std.debug.print("listen to address {s}:8000", .{ip});

    while (true) {
        try handleConnection(try server.accept(), db, allocator);
    }
}

fn handleConnection(conn: std.net.Server.Connection, db: ?*c.sqlite3, allocator: std.mem.Allocator) !void {
    defer conn.stream.close();
    var buffer: [1024]u8 = undefined;
    var http_server = std.http.Server.init(conn,&buffer);
    var req = try http_server.receiveHead();

    const path = req.head.target;
    std.debug.print("\npath: {s}", .{req.head.target});

    if (std.mem.eql(u8, path, "/")) {
        var html_buffer: [10240]u8 = undefined;
        const html_content = try std.fs.cwd().readFile("./ui.html", &html_buffer);
        try req.respond(html_content, .{
            .status = .ok
        });
    } else if (std.mem.eql(u8, path, "/favicon.svg")) {
        var favicon_buffer: [1024]u8 = undefined;
        const favicon_content = try std.fs.cwd().readFile("./favicon.svg", &favicon_buffer);
        try req.respond(favicon_content, .{
            .status = .ok,
            .extra_headers = &.{
                .{
                    .name = "Content-Type",
                    .value = "image/svg+xml",
                },
            }
        });
    } else if (std.mem.eql(u8, path, "/execute")) {
        const reader = try req.reader();
        const body_buffer = try reader.readAllAlloc(allocator, 1024 * 8);
        defer allocator.free(body_buffer);

        std.debug.print("\nReceived POST body: {s}", .{body_buffer});
        const result = try exec_sql_string(allocator, db, body_buffer.ptr);
        try req.respond(result, .{
            .extra_headers = &.{
                .{
                    .name = "Content-Type",
                    .value = "text/csv",
                },
            }
        });
    }

}
