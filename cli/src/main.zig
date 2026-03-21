// From a first-principle perspective, TTY (teletypewriter) is the underlying I/O abstraction layer that enables CLI applications to interact with users to other programs.
// CLI plays a role in interacting with the user through the terminal: text commands in, text results out.
// CLI is responsible for application logic.
// TTY is a character-oriented I/O device abstraction: handles input buffering, signal generation, line editing, output rendering.
const std = @import("std");
const cli = @import("cli");

pub fn main() !void {
    var allocator = std.heap.GeneralPurposeAllocator(.{ .safety = true }).init;
    const gpa = allocator.allocator();
    defer _ = allocator.deinit();

    const args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);

    if (args.len < 2) {
        try cli.printLarkCharacters();
        std.debug.print("\nUsage: {s} <command> \n  version\n  file\n  http\n", .{args[0]});
        std.process.exit(0);
    }

    if (std.mem.eql(u8, args[1], "version")) {
        std.debug.print("0.0.1\n", .{});
    }

    if (std.mem.eql(u8, args[1], "file")) {
        try std.fs.cwd().writeFile(.{ .data = "{}", .sub_path = "file.json" });
    }

    if (std.mem.eql(u8, args[1], "http")) {
        var client = std.http.Client{ .allocator = gpa };
        defer client.deinit();
        var buffer: [4096]u8 = undefined;
        var writer = std.io.Writer.fixed(&buffer);
        const result = try client.fetch(.{
            .method = .GET,
            .location = .{ .url = "https://baidu.com" },
            .response_writer = &writer,
        });
        std.debug.print("http response status: {d}\n", .{result.status});
        std.debug.print("http response body: {s}\n", .{writer.buffered()});
    }
}
