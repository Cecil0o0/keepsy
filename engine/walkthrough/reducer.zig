const std = @import("std");

/// A reducer is a function that takes an accumulator and a value, and returns a new accumulator
/// This is commonly used in functional programming for operations like sum, count, etc.
pub fn ReducerType(comptime T: type, comptime U: type) type {
    return *const fn (accumulator: T, value: U) T;
}

/// Example implementation of a sum reducer
pub fn sumReducer(accumulator: i32, value: i32) i32 {
    return accumulator + value;
}

/// Example implementation of a count reducer
pub fn countReducer(accumulator: usize, value: i32) usize {
    _ = value; // ignore the actual value, just count
    return accumulator + 1;
}

/// Example implementation of a max reducer
pub fn maxReducer(accumulator: i32, value: i32) i32 {
    return if (value > accumulator) value else accumulator;
}

/// Example implementation of a min reducer
pub fn minReducer(accumulator: i32, value: i32) i32 {
    return if (value < accumulator) value else accumulator;
}

/// Example implementation of a string concatenation reducer
pub fn stringReducer(allocator: std.mem.Allocator, accumulator: []const u8, value: []const u8) ![]const u8 {
    return try std.fmt.allocPrint(allocator, "{s}{s}", .{ accumulator, value });
}

/// Generic reduce function that applies a reducer function to an array of values
pub fn reduce(
    allocator: std.mem.Allocator,
    comptime T: type,
    comptime U: type,
    reducer: ReducerType(T, U),
    initial_value: T,
    values: []const U,
) T {
    _ = allocator;
    var result = initial_value;
    for (values) |value| {
        result = reducer(result, value);
    }
    return result;
}

/// Generic reduce function that works with slices and can return an error
pub fn reduceWithErrors(
    comptime T: type,
    comptime U: type,
    reducer: *const fn (T, U) error{OutOfMemory}!T,
    initial_value: T,
    values: []const U,
) error{OutOfMemory}!T {
    var result = initial_value;
    for (values) |value| {
        result = try reducer(result, value);
    }
    return result;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Example 1: Sum reduction
    const numbers = [_]i32{ 1, 2, 3, 4, 5 };
    const sum = reduce(allocator, i32, i32, sumReducer, 0, &numbers);
    std.debug.print("Sum: {d}\n", .{sum});

    // Example 2: Count reduction
    const count = reduce(allocator, usize, i32, countReducer, 0, &numbers);
    std.debug.print("Count: {d}\n", .{count});

    // Example 3: Max reduction
    const max = reduce(allocator, i32, i32, maxReducer, std.math.minInt(i32), &numbers);
    std.debug.print("Max: {d}\n", .{max});

    // Example 4: Min reduction
    const min = reduce(allocator, i32, i32, minReducer, std.math.maxInt(i32), &numbers);
    std.debug.print("Min: {d}\n", .{min});

    // Example 5: String concatenation
    const words = [_][]const u8{ "Hello", " ", "World", "!" };
    var result: []const u8 = try allocator.dupe(u8, "");
    for (words) |word| {
        result = try stringReducer(allocator, result, word);
    }
    std.debug.print("Concatenated: {s}\n", .{result});
    allocator.free(result);

    // Example 6: Using reduceWithErrors for operations that might fail
    // Here we'll create a reducer that converts strings to numbers and sums them
    const string_numbers = [_][]const u8{ "10", "20", "30", "40" };
    var sum_result: i32 = 0;
    for (string_numbers) |str_num| {
        const num = try std.fmt.parseInt(i32, str_num, 10);
        sum_result = sumReducer(sum_result, num);
    }
    std.debug.print("Sum from string numbers: {d}\n", .{sum_result});

    // Example 7: Implementing a reducer for finding average
    const avg_data = [_]i32{ 10, 20, 30, 40, 50 };
    const total = reduce(allocator, i32, i32, sumReducer, 0, &avg_data);
    const avg = @divExact(total, @as(i32, @intCast(avg_data.len)));
    std.debug.print("Average: {d}\n", .{avg});

    // Example 8: Complex reducer - filtering and mapping in one pass
    // This reducer only accumulates even numbers
    const even_numbers = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
    var even_sum: i32 = 0;
    for (even_numbers) |num| {
        if (num % 2 == 0) {
            even_sum = sumReducer(even_sum, num);
        }
    }
    std.debug.print("Sum of even numbers: {d}\n", .{even_sum});
}

test "reduce with sum" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const numbers = [_]i32{ 1, 2, 3, 4, 5 };
    const result = reduce(allocator, i32, i32, sumReducer, 0, &numbers);
    try std.testing.expectEqual(@as(i32, 15), result);
}

test "reduce with count" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const numbers = [_]i32{ 1, 2, 3, 4, 5 };
    const result = reduce(allocator, usize, i32, countReducer, 0, &numbers);
    try std.testing.expectEqual(@as(usize, 5), result);
}

test "reduce with max" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const numbers = [_]i32{ 1, 5, 3, 9, 2 };
    const result = reduce(allocator, i32, i32, maxReducer, std.math.minInt(i32), &numbers);
    try std.testing.expectEqual(@as(i32, 9), result);
}

test "reduce with min" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const numbers = [_]i32{ 1, 5, 3, 9, 2 };
    const result = reduce(allocator, i32, i32, minReducer, std.math.maxInt(i32), &numbers);
    try std.testing.expectEqual(@as(i32, 1), result);
}
