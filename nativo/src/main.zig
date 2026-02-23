const std = @import("std");
const nativo = @import("nativo");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    if (args.len < 2) {
        std.debug.print("Usage: {s} <html_file_path>\n", .{args[0]});
        return error.MissingArgument;
    }
    defer std.process.argsFree(allocator, args);
    std.debug.print("html {s}\n", .{args[1]});
    const manifest = try nativo.get_manifest_from_html(
        allocator,
        std.fs.cwd().readFileAlloc(allocator, args[1], 4096) catch |err| {
            std.debug.print("Error: {any}\n", .{err});
            return;
        },
    );
    std.debug.print("\n", .{});
    for (manifest) |module| {
        std.debug.print("module {s}\n", .{module});
    }
}
