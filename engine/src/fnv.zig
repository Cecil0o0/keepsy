pub fn fnv_1a(bytes: []const u8) u32 {
    const prime: u32 = 16777619;
    const offset_basis: u32 = 2166136261;

    var hash: u32 = offset_basis;
    for (bytes) |byte| {
        hash ^= @as(u32, byte);
        hash *%= prime; // wrapping multiplication
    }
    return hash;
}

test "functionality" {
    const std = @import("std");
    std.debug.print("\nfnv_1a result: {x} for 'Hello world!'.\n", .{fnv_1a("Hi")});
    std.debug.print("fnv_1a result: {x} for 'hi'.\n", .{fnv_1a("hi")});
    try std.testing.expectEqual(0x67eb44ba, fnv_1a("Hi"));
    try std.testing.expectEqual(0x683af69a, fnv_1a("hi"));
}

test "performance" {
    const std = @import("std");
    const bytes = "hi";
    const start = std.time.nanoTimestamp();
    var i: u64 = 0;
    const iterations = 1_000_000;
    while (i < iterations) : (i += 1) {
        _ = fnv_1a(bytes);
    }
    std.debug.print("\nElapsed {d}ms for {d} iterations.\n", .{ @as(i64, @intCast(@divFloor((std.time.nanoTimestamp() - start), std.time.ns_per_ms))), iterations });
}
