const std = @import("std");

fn embedding(text: []const u8) @Vector(16, u8) {
    var vec: @Vector(16, u8) = @splat(0);
    for (text) |c| {
        std.debug.print("{c}:{x} ", .{ c, c });
    }
    vec = @splat(@as(u8, text[0]));
    return vec;
}

fn embedding_for_nlp() void {}

test "embedding" {
    const text = "Test";
    const actual = embedding(text);
    var arr: [16]u8 = undefined;
    @memcpy(arr[0..], @as([*]const u8, @ptrCast(&actual))[0..16]);
    std.debug.print("\n{}", .{actual});
}
