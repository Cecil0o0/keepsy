/// The data engine aims to provide an optimal approach to storage and access data in cloud environment.
/// The purpose could be:
/// - Make every aspect explicit, improve trustworthiness of system.
/// - Minimal latency and Maximum throughput for both read and write in cloud environment.
/// - Scale efficiently with data volumn and concurrent access without sacrificing consistency or durability.
/// - Optimize resource utilization(CPU, Memory, I/O, Network) to reduce operational cost in cloud infrastracture.
/// To achieve this goal:
/// - I have chosen sqlite3 as the underlying database engine, provide a simple and reliable file api.
/// - Deploy the software into a cloud environment to be a cloud-native application for scalability.
///
/// I won't:
/// - Due to purpose of understanding deeply, I decide to build it on top of any other bigdata computing service like MaxCompute.
/// - For implementing focusly within limited time and resource, I decide to reserve space and interface for data access control.
///
/// Software is programs, data, and documents—but the program is its core: the set of instructions that make the computer act. I focus on the program, not the language.
/// A data engine is defined not by the language it’s written in, but by how that language is applied to solve real problems in data storage and access. Zig—explicit, minimal, and zero-overhead—keeps the focus where it belongs: on the data, not the syntax.
const std = @import("std");
/// SQLite3 is the Most Widely Deployed and Used database engine.
/// Zig compiler is powerful, it can compile with C code, provided interoperability with C ecosystem. While it can even compile C code directly if necessary.
/// The SQLite library consists of 111 files of C code in the core with 22 additional files that implement certain commonly used extensions.
const c = @cImport({
    @cInclude("sqlite_amalgamation.h");
});
/// We provide several accessible approaches to interact with the data engine, such as web UI, API, and command line interface, for our users with different backends and needs.
/// Here is the API tier. [httpz](https://github.com/karlseguin/http.zig) is the web framework for building high-performance web applications in Zig, we choose it because it is zig-native with a focus on performance and simplicity.
const httpz = @import("httpz");

const App = struct { path_to_db_file: []const u8, db: ?*c.sqlite3, allocator: std.mem.Allocator, db_mutex: std.Thread.Mutex };

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var db: ?*c.sqlite3 = undefined;
    const path_to_db_file = "../system.db";
    const open_result = c.sqlite3_open(path_to_db_file, &db);
    defer _ = c.sqlite3_close(db);
    if (open_result != c.SQLITE_OK) {
        std.debug.print("error: {s}\n", .{c.sqlite3_errmsg(db)});
        return error.OpenError;
    }

    // to use WAL journal_mode for better performance.
    // to use DELETE journal_mode for normal behavior.
    _ = c.sqlite3_exec(db, "PRAGMA journal_mode=DELETE;", null, null, null);

    var app = App{ .path_to_db_file = path_to_db_file, .db = db, .allocator = allocator, .db_mutex = .{} };

    std.debug.print("Open '{s}' success!\nThe version of database engine: {s}\n", .{ path_to_db_file, c.sqlite3_version });

    // We can use a custom `Handler` to handle more complex requests with required reference object.
    // To pass `db` and `allocator` to do the specific action of current engine
    var server = try httpz.Server(*App).init(allocator, .{ .address = "0.0.0.0", .port = 8000 }, &app);
    defer {
        // clean shutdown, finishes serving any live request
        server.stop();
        server.deinit();
    }

    var router = try server.router(.{});
    // to serve a webpage for accessing this data engine
    router.get("/", index, .{});
    // to serve a webpage for editor
    router.get("/editor", editor, .{});
    // to serve a icon for the webpage
    router.get("/favicon.svg", favicon, .{});
    // to interact with vipserver, the load balancer for ingress.
    router.get("/healthcheck", healthcheck, .{});
    // to explore the database, such as tables, schemas, output modes
    router.get("/explore", explore, .{});
    // to serve as an interpreter for sql query
    router.post("/interpret", interpret, .{});

    std.debug.print("Listening on port 8000.\n", .{});

    // blocks
    try server.listen();
}

fn index(_: *App, _: *httpz.Request, res: *httpz.Response) !void {
    res.status = 200;
    var html_buffer: [8192]u8 = undefined;
    const html_content = try std.fs.cwd().readFile("./ui.html", &html_buffer);
    res.body = html_content;
    try res.write();
}

fn editor(_: *App, _: *httpz.Request, res: *httpz.Response) !void {
    res.status = 200;
    var html_buffer: [8192]u8 = undefined;
    const html_content = try std.fs.cwd().readFile("./editor.html", &html_buffer);
    res.body = html_content;
    try res.write();
}

fn favicon(_: *App, _: *httpz.Request, res: *httpz.Response) !void {
    var buffer: [8192]u8 = undefined;
    const file = try std.fs.cwd().readFile("./favicon.svg", &buffer);
    res.body = file;
    res.headers.add("Content-Type", "image/svg+xml;");
    try res.write();
}

fn healthcheck(_: *App, _: *httpz.Request, res: *httpz.Response) !void {
    res.body = "ok";
    try res.write();
}

fn explore(app: *App, _: *httpz.Request, res: *httpz.Response) !void {
    const run_result = try std.process.Child.run(.{
        .allocator = app.allocator,
        .argv = &.{ "sqlite3", app.path_to_db_file, ".tables" },
    });
    std.debug.print("{s}", .{run_result.stdout});

    if (run_result.term.Exited > 0) {
        res.body = run_result.stderr;
    }
    res.body = run_result.stdout;
    try res.write();
}

const CallbackContextForCSVFormat = struct { writer: std.ArrayList(u8).Writer, allocator: std.mem.Allocator, has_csv_header: bool };
pub fn callback(callback_ptr: ?*anyopaque, column_count: c_int, column_value: [*c][*c]u8, column_name: [*c][*c]u8) callconv(.c) c_int {
    if (callback_ptr) |context_ptr| {
        const context: *CallbackContextForCSVFormat = @ptrCast(@alignCast(context_ptr));
        std.debug.print("the column_count of current query is {any}.\n", .{column_count});
        if (context.has_csv_header == false) {
            for (0..@intCast(column_count)) |i| {
                std.debug.print("[header] {s}\n", .{column_name[i]});
                context.writer.print("{s},", .{column_name[i]}) catch return 1;
            }
            context.writer.print("\n", .{}) catch return 1;
            context.has_csv_header = true;
        }
        for (0..@intCast(column_count)) |i| {
            // see whether the pointer to a slice is a null pointer
            // if yes, just print NULL to indicate the absence of a value
            if (column_value[i] == null) {
                std.debug.print("[body] {d} NULL\n", .{i});
                context.writer.print("NULL,", .{}) catch return 1;
                continue;
            }
            std.debug.print("[body] {d} {s}...(length: {d})\n", .{ i, column_value[i][0..10], std.mem.len(column_value[i]) });
            context.writer.print("{s},", .{column_value[i]}) catch |err| switch (err) {
                error.OutOfMemory => {
                    std.debug.print("Out of memory, Please increase the heap size.\n", .{});
                    return 1;
                },
            };
        }
        context.writer.print("\n", .{}) catch return 1;
    }

    return 0;
}

fn interpret(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    app.db_mutex.lock();
    defer app.db_mutex.unlock();

    const req_body = req.body().?;
    if (req.body_len == 0) {
        res.body = "There is no sql in response body to interpret, please send sql query in body";
        res.status = 400;
        res.headers.add("Content-Type", "text/plain;charset=UTF-8");
    }

    // prepare a cstring for sqlite3_exec to read from.
    const sql_z = try std.fmt.allocPrintSentinel(app.allocator, "{s}", .{req_body}, 0);
    defer app.allocator.free(sql_z);
    std.debug.print("\nIncoming body: {s}\n", .{sql_z});

    var dur_ns = std.time.nanoTimestamp();
    var csv = std.ArrayList(u8){};
    defer csv.deinit(app.allocator);
    var callback_context_for_csv_format = CallbackContextForCSVFormat{ .writer = csv.writer(app.allocator), .allocator = app.allocator, .has_csv_header = false };
    var err_msg: [*c]u8 = undefined;
    defer if (err_msg) |msg| c.sqlite3_free(msg);
    // reference: https://sqlite.org/c3ref/exec.html
    const exec_result = c.sqlite3_exec(app.db, sql_z.ptr, &callback, &callback_context_for_csv_format, &err_msg);
    var result: []u8 = undefined;
    switch (exec_result) {
        c.SQLITE_OK => {
            std.debug.print("\nExecute Success!", .{});
            result = try csv.toOwnedSlice(app.allocator);
        },
        c.SQLITE_ERROR => {
            std.debug.print("\nError: {s}", .{err_msg});
            result = std.mem.span(err_msg);
        },
        else => {
            std.debug.print("\nUnknown Error: {s}", .{err_msg});
            result = std.mem.span(err_msg);
        },
    }
    dur_ns = std.time.nanoTimestamp() - dur_ns;
    res.headers.add("Content-Type", "text/csv;charset=UTF-8");
    var buf: [64]u8 = undefined;
    std.debug.print("\nExecute time: {d}μs", .{@divTrunc(dur_ns, 1000)});
    res.headers.add("Server-Timing", try std.fmt.bufPrint(&buf, "interpret;dur={d}", .{@divTrunc(dur_ns, 1000_000)}));
    if (result.len > 0) {
        res.body = result;
    } else {
        res.body = "No result";
    }
    try res.write();
    std.debug.print("\n", .{});
}

/// symbols for testing
var is_done = std.atomic.Value(bool).init(false);
fn timeout() void {
    std.debug.print("start to sleep 1 second.\n", .{});
    std.Thread.sleep(1000_000_000);
    is_done.store(true, .release);
    std.debug.print("terminate to sleep 1 second.\n", .{});
}
fn operate(db: ?*c.sqlite3) void {
    std.debug.print("start to insert in an infinite loop.\n", .{});
    var i: i32 = 0;
    while (true) {
        if (is_done.load(.acquire)) {
            std.debug.print("terminate to insert. {d} ops\n", .{i});
            break;
        }
        _ = c.sqlite3_exec(db, "insert into tb3 values(\"wrk11\",100,\"RAM User\",\"xxx\",\"1107550004253538\",\"1107550004253538\");", null, null, null);
        i += 1;
    }
}

test "ops" {
    var db: ?*c.sqlite3 = undefined;
    const open_result = c.sqlite3_open("../benchmark_ops.db", &db);
    defer _ = c.sqlite3_close(db);
    if (open_result != c.SQLITE_OK) {
        std.debug.print("\nError: {s}", .{c.sqlite3_errmsg(db)});
        return error.OpenDBError;
    }
    // preset the database
    _ = c.sqlite3_exec(db, "PRAGMA journal_mode=DELETE;", null, null, null);
    _ = c.sqlite3_exec(db, "CREATE TABLE if not exists tb3 (name string, age int, principle string, role string, uid string, account string);", null, null, null);
    const thread_for_inifinite_operating = try std.Thread.spawn(.{}, operate, .{db});
    const thread_for_finite_timeout = try std.Thread.spawn(.{}, timeout, .{});
    thread_for_inifinite_operating.join();
    thread_for_finite_timeout.join();

    var csv = std.ArrayList(u8){};
    defer csv.deinit(std.testing.allocator);
    var callback_context_for_csv_format = CallbackContextForCSVFormat{ .writer = csv.writer(std.testing.allocator), .allocator = std.testing.allocator, .has_csv_header = false };
    _ = c.sqlite3_exec(db, "select count(*) from tb3;", callback, &callback_context_for_csv_format, null);
    // always consider success for executing a simple sql.
    std.debug.print("{s}\n", .{csv.items});
}
