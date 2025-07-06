extern fn print(u8s: [*c]u8) void;
extern fn print_string(ptr: [*c]u8, len: u32) void;

pub export fn add(a: i32, b: i32) i32 {
    print(a + b);
    return a + b;
}

pub export fn tokenize(ptr: [*]u8, len: usize) i32 {
    const source: []u8 = ptr[0..len];
    const std = @import("std");
    var arr: std.ArrayList(u8) = std.ArrayList(u8).init(std.heap.wasm_allocator);
    arr.appendSlice(source) catch unreachable;
    print_string(arr.items.ptr, @intCast(arr.items.len));
    return @intCast(arr.items.len);
}
