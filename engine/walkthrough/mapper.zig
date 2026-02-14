const std = @import("std");
const builtin = @import("builtin");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

/// Generic mapper for large-scale data processing
pub fn DataMapper(
    comptime InputType: type,
    comptime OutputType: type,
    comptime mapFn: fn (InputType, *Allocator) anyerror!OutputType,
) type {
    return struct {
        const Self = @This();

        allocator: *Allocator,
        chunk_size: usize = 1000,
        parallel: bool = false,

        pub fn init(allocator: *Allocator) Self {
            return Self{
                .allocator = allocator,
                .chunk_size = 1000,
                .parallel = false,
            };
        }

        /// Process a single record
        pub fn mapOne(self: *Self, input: InputType) !OutputType {
            return try mapFn(input, self.allocator);
        }

        /// Process a list of records sequentially
        pub fn mapList(self: *Self, inputs: []const InputType) !ArrayList(OutputType) {
            var results = try std.ArrayList(OutputType).initCapacity(self.allocator.*, inputs.len);
            errdefer results.deinit(self.allocator.*);

            for (inputs) |input| {
                const output = try mapFn(input, self.allocator);
                try results.append(self.allocator.*, output);
            }

            return results;
        }

        /// Process records in chunks for memory efficiency
        pub fn mapChunks(self: *Self, inputs: []const InputType) !ArrayList(OutputType) {
            var results = try std.ArrayList(OutputType).initCapacity(self.allocator.*, inputs.len);
            errdefer results.deinit(self.allocator.*);

            var i: usize = 0;
            while (i < inputs.len) {
                const end = @min(i + self.chunk_size, inputs.len);
                const chunk = inputs[i..end];

                if (self.parallel and inputs.len > self.chunk_size) {
                    var chunk_results = try self.mapListParallel(chunk);
                    try results.appendSlice(self.allocator.*, chunk_results.items);
                    chunk_results.deinit(self.allocator.*);
                } else {
                    var chunk_results = try self.mapList(chunk);
                    try results.appendSlice(self.allocator.*, chunk_results.items);
                    chunk_results.deinit(self.allocator.*);
                }

                i = end;
            }

            return results;
        }

        /// Parallel processing using threads (when available)
        fn mapListParallel(self: *Self, inputs: []const InputType) !ArrayList(OutputType) {
            if (builtin.single_threaded or inputs.len < 10) {
                // Fall back to sequential processing if single-threaded or small input
                return try self.mapList(inputs);
            }

            const thread_count = @min(4, inputs.len);
            const chunk_size = @max(1, inputs.len / thread_count);

            var threads: [4]std.Thread = undefined;
            var result_lists: [4]ArrayList(OutputType) = undefined;

            var thread_idx: usize = 0;
            var i: usize = 0;
            while (i < inputs.len) : (i += chunk_size) {
                if (thread_idx >= thread_count) break;

                const end = @min(i + chunk_size, inputs.len);
                const thread_inputs = inputs[i..end];

                result_lists[thread_idx] = try std.ArrayList(OutputType).initCapacity(self.allocator.*, thread_inputs.len);
                try result_lists[thread_idx].ensureTotalCapacity(self.allocator.*, thread_inputs.len);

                threads[thread_idx] = try std.Thread.spawn(.{}, mapChunk, .{
                    thread_inputs,
                    &result_lists[thread_idx],
                    self.allocator,
                });

                thread_idx += 1;
            }

            // Wait for all threads to complete
            var j: usize = 0;
            while (j < thread_idx) : (j += 1) {
                threads[j].join();
            }

            // Combine results
            var final_results = try std.ArrayList(OutputType).initCapacity(self.allocator.*, inputs.len);
            errdefer final_results.deinit(self.allocator.*);

            j = 0;
            while (j < thread_idx) : (j += 1) {
                try final_results.appendSlice(self.allocator.*, result_lists[j].items);
                result_lists[j].deinit(self.allocator.*);
            }

            return final_results;
        }

        /// Worker function for thread processing
        fn mapChunk(inputs: []const InputType, results: *ArrayList(OutputType), allocator: *Allocator) !void {
            for (inputs) |input| {
                const output = try mapFn(input, allocator);
                try results.append(allocator.*, output);
            }
        }
    };
}

/// Streaming data processor for very large datasets that don't fit in memory
pub fn StreamMapper(
    comptime InputType: type,
    comptime OutputType: type,
    comptime mapFn: fn (InputType, *Allocator) anyerror!OutputType,
) type {
    return struct {
        const Self = @This();

        allocator: Allocator,
        buffer_size: usize = 10000,

        pub fn init(allocator: Allocator) Self {
            return Self{
                .allocator = allocator,
                .buffer_size = 10000,
            };
        }

        /// Process a stream of data from a reader
        pub fn processStream(self: *Self, reader: anytype, writer: anytype) !void {
            var buffer: [1024]u8 = undefined;
            var input_buffer = ArrayList(InputType).init(self.allocator);
            defer input_buffer.deinit();

            var output_buffer = ArrayList(OutputType).init(self.allocator);
            defer output_buffer.deinit();

            while (true) {
                // Read inputs until buffer is full or EOF
                while (input_buffer.items.len < self.buffer_size) {
                    if (try self.readOne(reader, &buffer)) |input| {
                        try input_buffer.append(input);
                    } else {
                        break; // EOF
                    }
                }

                if (input_buffer.items.len == 0) {
                    break; // No more data
                }

                // Process the buffer
                for (input_buffer.items) |input| {
                    const output = try mapFn(input, self.allocator);
                    try output_buffer.append(output);
                }

                // Write outputs
                for (output_buffer.items) |output| {
                    try self.writeOne(writer, output);
                }

                // Clear buffers for next iteration
                input_buffer.clearRetainingCapacity();
                output_buffer.clearRetainingCapacity();
            }
        }

        /// Read one item from the stream (implementation depends on data format)
        fn readOne(self: *Self, reader: anytype, buffer: []u8) !?InputType {
            // This is a simplified example - real implementation would depend on your data format
            _ = self;
            _ = reader;
            _ = buffer;

            // For demo purposes, return null to indicate EOF
            return null;
        }

        /// Write one item to the output
        fn writeOne(self: *Self, writer: anytype, output: OutputType) !void {
            _ = self;
            try writer.print("{any}\n", .{output});
        }
    };
}

// Example usage functions
fn stringToIntMapper(input: []const u8, allocator: *Allocator) !i32 {
    _ = allocator;
    return std.fmt.parseInt(i32, input, 10) catch 0;
}

fn intToStringMapper(input: i32, allocator: *Allocator) ![]u8 {
    const result = try std.fmt.allocPrint(allocator.*, "processed_{any}", .{input});
    return result;
}

fn addTenMapper(input: i32, allocator: *Allocator) !i32 {
    _ = allocator;
    return input + 10;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var allocator = gpa.allocator();

    // Example 1: Basic mapping
    std.debug.print("=== Basic Mapping Example ===\n", .{});

    var mapper = DataMapper([]const u8, i32, stringToIntMapper).init(&allocator);
    const inputs = [_][]const u8{ "10", "20", "30", "40", "50" };

    var results = try mapper.mapList(&inputs);
    defer results.deinit(allocator);

    std.debug.print("String to int results: ", .{});
    for (results.items) |result| {
        std.debug.print("{d} ", .{result});
    }
    std.debug.print("\n", .{});

    // Example 2: Mapping with transformation
    std.debug.print("\n=== Transformation Example ===\n", .{});

    var intMapper = DataMapper(i32, i32, addTenMapper).init(&allocator);
    intMapper.chunk_size = 2; // Small chunks for demonstration

    const intInputs = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
    var intResults = try intMapper.mapChunks(&intInputs);
    defer intResults.deinit(allocator);

    std.debug.print("Add 10 to each: ", .{});
    for (intResults.items) |result| {
        std.debug.print("{d} ", .{result});
    }
    std.debug.print("\n", .{});

    // Example 3: Parallel processing demonstration
    std.debug.print("\n=== Parallel Processing Example ===\n", .{});

    var parallelMapper = DataMapper(i32, []u8, intToStringMapper).init(&allocator);
    parallelMapper.parallel = true;
    parallelMapper.chunk_size = 3;

    const largeInputs = [_]i32{ 100, 200, 300, 400, 500, 600, 700, 800, 900, 1000 };
    var parallelResults = try parallelMapper.mapChunks(&largeInputs);
    defer {
        for (parallelResults.items) |item| {
            allocator.free(item);
        }
        parallelResults.deinit(allocator);
    }

    std.debug.print("Parallel processed results:\n", .{});
    for (parallelResults.items) |result| {
        std.debug.print("{s}\n", .{result});
    }

    // Example 4: Performance metrics
    std.debug.print("\n=== Performance Example ===\n", .{});

    const start_time = std.time.milliTimestamp();
    var perfMapper = DataMapper(i32, i32, addTenMapper).init(&allocator);

    // Create a larger dataset for performance testing
    var perfInputs = try ArrayList(i32).initCapacity(allocator, 10000);
    defer perfInputs.deinit(allocator);

    var i: usize = 0;
    while (i < 10000) : (i += 1) {
        try perfInputs.append(allocator, @intCast(i));
    }

    var perfResults = try perfMapper.mapChunks(perfInputs.items);
    defer perfResults.deinit(allocator);

    const end_time = std.time.milliTimestamp();
    const duration = @abs(end_time - start_time);

    std.debug.print("Processed {any} items in {d}ms\n", .{ perfInputs.items.len, duration });
    std.debug.print("First 10 results: ", .{});
    const limit = @min(10, perfResults.items.len);
    for (perfResults.items[0..limit]) |result| {
        std.debug.print("{d} ", .{result});
    }
    std.debug.print("\n", .{});

    std.debug.print("\nMapper program completed successfully!\n", .{});
}

// Additional utility functions for working with files
pub fn processFile(
    comptime InputType: type,
    comptime OutputType: type,
    allocator: *Allocator,
    input_filename: []const u8,
    output_filename: []const u8,
    comptime process_fn: fn (InputType, *Allocator) anyerror!OutputType,
) !void {
    const input_file = try std.fs.cwd().openFile(input_filename, .{});
    defer input_file.close();

    const output_file = try std.fs.cwd().createFile(output_filename, .{});
    defer output_file.close();

    var buf_reader = std.io.bufferedReader(input_file.reader());
    const reader = buf_reader.reader();

    var buf_writer = std.io.bufferedWriter(output_file.writer());
    const writer = buf_writer.writer();

    var line_buffer: [1024]u8 = undefined;
    while (try reader.readUntilDelimiterOrEof(&line_buffer, '\n')) |line| {
        // Parse the input, process it, and write the output
        const input = try allocator.dupe(u8, line);
        defer allocator.free(input);

        const output = try process_fn(input, allocator);
        try writer.print("{any}\n", .{output});

        // Handle output based on its type (this would need to be more specific based on OutputType)
        if (comptime std.meta.trait.isZigString(@TypeOf(output))) {
            allocator.free(output);
        }
    }

    try buf_writer.flush();
}

test "basic mapper functionality" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var allocator = gpa.allocator();

    var mapper = DataMapper([]const u8, i32, stringToIntMapper).init(&allocator);
    const inputs = [_][]const u8{ "5", "15", "25" };

    var results = try mapper.mapList(&inputs);
    defer results.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 3), results.items.len);
    try std.testing.expectEqual(@as(i32, 5), results.items[0]);
    try std.testing.expectEqual(@as(i32, 15), results.items[1]);
    try std.testing.expectEqual(@as(i32, 25), results.items[2]);
}

test "mapper with chunks" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var allocator = gpa.allocator();

    var mapper = DataMapper(i32, i32, addTenMapper).init(&allocator);
    mapper.chunk_size = 2;

    const inputs = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 };
    var results = try mapper.mapChunks(&inputs);
    defer results.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 12), results.items.len);
    try std.testing.expectEqual(@as(i32, 11), results.items[0]);
    try std.testing.expectEqual(@as(i32, 12), results.items[1]);
    try std.testing.expectEqual(@as(i32, 13), results.items[2]);
    try std.testing.expectEqual(@as(i32, 14), results.items[3]);
    try std.testing.expectEqual(@as(i32, 15), results.items[4]);
    try std.testing.expectEqual(@as(i32, 16), results.items[5]);
    try std.testing.expectEqual(@as(i32, 17), results.items[6]);
    try std.testing.expectEqual(@as(i32, 18), results.items[7]);
    try std.testing.expectEqual(@as(i32, 19), results.items[8]);
    try std.testing.expectEqual(@as(i32, 20), results.items[9]);
}
