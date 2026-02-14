/// The nature of compression is redundancy in data, the fundamental principle of data compression is the exploitation of redundancy.
/// redundancy means predicatable or repeated structure that can be describe more concisely, like LZ77.
/// compression is different from encryption and mangling, which are different aspects of data processing.
/// compression used everyday and everywhere, such as zstd, deflate, etc.
/// Deflate is a compression algorithm who consists of LZ77 and Huffman coding.
/// To describe LZ77, for example "hello hello" => "hello (6,5)", where 6 stands distance to go back in bytes and 5 represents the length in bytes. After LZ77, this 11-bytes string will be compressed in 8~9 bytes.
const std = @import("std");

/// Used for compress data produced data engine
pub fn compress(allocator: std.mem.Allocator, data: []const u8) ![]const u8 {
    if (data.len == 0) return allocator.dupe(u8, data);

    // LZ77 parameters
    const WINDOW_SIZE = 4096;
    const MAX_MATCH_LENGTH = 258;
    const MIN_MATCH_LENGTH = 3;
    const MATCH_MARKER = 0xFF;

    var result = std.ArrayListUnmanaged(u8){};
    defer result.deinit(allocator);

    var pos: usize = 0;

    while (pos < data.len) {
        var best_distance: usize = 0;
        var best_length: usize = 0;

        // Search for the longest match in the sliding window
        const max_search = @min(pos, WINDOW_SIZE);

        for (0..max_search) |offset| {
            const search_pos = pos - offset - 1;
            var match_len: usize = 0;

            while (match_len < MAX_MATCH_LENGTH and
                pos + match_len < data.len and
                data[search_pos + match_len] == data[pos + match_len])
            {
                match_len += 1;
            }

            if (match_len > best_length and match_len >= MIN_MATCH_LENGTH) {
                best_length = match_len;
                best_distance = offset + 1;
            }
        }

        if (best_length >= MIN_MATCH_LENGTH) {
            // Write match marker, distance, and length
            try result.append(allocator, MATCH_MARKER);
            try result.append(allocator, @intCast(best_distance >> 8));
            try result.append(allocator, @intCast(best_distance & 0xFF));
            try result.append(allocator, @intCast(best_length & 0xFF));
            pos += best_length;
        } else {
            // Write literal byte
            try result.append(allocator, data[pos]);
            pos += 1;
        }
    }

    return result.toOwnedSlice(allocator);
}

/// Used to decompress data that was compressed by the compress function
pub fn decompress(allocator: std.mem.Allocator, compressed: []const u8) ![]const u8 {
    if (compressed.len == 0) return allocator.dupe(u8, compressed);

    const MATCH_MARKER = 0xFF;

    var result = std.ArrayListUnmanaged(u8){};
    defer result.deinit(allocator);

    var pos: usize = 0;

    while (pos < compressed.len) {
        const byte = compressed[pos];

        if (byte == MATCH_MARKER) {
            // Read match: marker + distance (2 bytes) + length (1 byte)
            if (pos + 3 >= compressed.len) return error.InvalidCompressedData;

            const distance_high = compressed[pos + 1];
            const distance_low = compressed[pos + 2];
            const length = compressed[pos + 3];

            const distance: usize = (@as(usize, distance_high) << 8) | distance_low;

            // Copy from the output buffer
            const start_pos = result.items.len - distance;
            for (0..length) |i| {
                try result.append(allocator, result.items[start_pos + i]);
            }

            pos += 4;
        } else {
            // Literal byte
            try result.append(allocator, byte);
            pos += 1;
        }
    }

    return result.toOwnedSlice(allocator);
}

test "compression and decompression" {
    const data = "Hello, world!    !!!xaaaaaccc Hello, world!";
    const compressed = try compress(std.heap.page_allocator, data);
    const decompressed = try decompress(std.heap.page_allocator, compressed);

    std.debug.print("Compressed data ({d} bytes): {s}\n", .{ compressed.len, compressed });
    std.debug.print("Decompressed data ({d} bytes): {s}\n", .{ decompressed.len, decompressed });
    std.debug.print("compression rate: {d}%\n", .{(data.len - compressed.len) * 100 / data.len});
    try std.testing.expectEqualStrings(data, decompressed);

    // Cleanup
    std.heap.page_allocator.free(compressed);
    std.heap.page_allocator.free(decompressed);
}
