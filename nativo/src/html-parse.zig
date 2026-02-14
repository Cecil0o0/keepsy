/// This module is responsible for parsing HTML files in a modern lexerless way.
/// It is a recursive descent parser with one-pass over the input.
/// For the optimal implementation, I write this parser by hand without using any parser generator.
/// Zig is general purpose programming language for systems development, I need it to provide high-performance and maintainability.
const std = @import("std");

fn parse(html: []const u8) !void {
    // skip whitespace and comments

    var i: usize = 0;
    while (i < html.len) : (i += 1) {
        const c = html[i];

        // Skip whitespace
        if (std.ascii.isWhitespace(c)) {
            continue;
        }

        // Skip HTML comments <!-- ... -->
        if (i + 3 < html.len and html[i] == '<' and html[i + 1] == '!' and html[i + 2] == '-' and html[i + 3] == '-') {
            i += 4;
            // Find the end of comment -->
            while (i + 2 < html.len) : (i += 1) {
                if (html[i] == '-' and html[i + 1] == '-' and html[i + 2] == '>') {
                    i += 2;
                    break;
                }
            }
            continue;
        }

        // If we found non-whitespace, non-comment content, break to process it
        break;
    }

    // i is now at the first non-whitespace, non-comment character
    while (i < html.len) {
        // detect the character sequence <!DOCTYPE html>
        if (i + 14 < html.len and html[i] == '<' and html[i + 1] == '!') {
            // Check for DOCTYPE case-insensitively
            var match = true;
            const doctype = "DOCTYPE";
            for (doctype, 0..) |expected_char, offset| {
                const actual_char = html[i + 2 + offset];
                if (std.ascii.toLower(actual_char) != std.ascii.toLower(expected_char)) {
                    match = false;
                    break;
                }
            }

            if (match and html[i + 10] == ' ') {
                // Check for "html" case-insensitively
                const html_str = "html";
                var html_match = true;
                for (html_str, 0..) |expected_char, offset| {
                    const actual_char = html[i + 11 + offset];
                    if (std.ascii.toLower(actual_char) != std.ascii.toLower(expected_char)) {
                        html_match = false;
                        break;
                    }
                }

                if (html_match) {
                    i += 14;
                    continue;
                }
            }

            if (match == false) return error.InvalidDOCTYPE;
        }
        i += 1;
    }
}

test "html_parse" {
    const html = "<!-- this is comment --><!DOCTYPE html><html><head></head><body></body></html>";
    _ = try parse(html);
}
