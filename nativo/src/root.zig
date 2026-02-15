//! By convention, root.zig is the root source file when making a library.
const std = @import("std");
const html_parse = @import("./html-parse.zig");

pub fn get_manifest_from_html(allocator: std.mem.Allocator, html: []const u8) ![][]const u8 {
    const elements = try html_parse.parse(allocator, html);
    defer allocator.free(elements);
    var manifest = try std.ArrayList([]const u8).initCapacity(allocator, 10);
    defer manifest.deinit(allocator);
    for (elements) |element| {
        if (std.mem.eql(u8, element.tagName, "script")) {
            if (element.attributes) |attributes| {
                for (attributes) |attribute| {
                    if (std.mem.startsWith(u8, attribute.name, "src")) {
                        try manifest.append(allocator, attribute.value.?);
                    }
                }
                allocator.free(attributes);
            }
        }
    }
    return manifest.toOwnedSlice(allocator);
}

test "get manifest from a html file" {
    const gpa = std.testing.allocator;
    const html = @embedFile("./usecase/test.html");
    const manifest = try get_manifest_from_html(gpa, html);
    defer gpa.free(manifest);
    try std.testing.expectEqual(@as(usize, 1), manifest.len);
}
