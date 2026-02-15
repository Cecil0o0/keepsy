/// This module is responsible for parsing HTML files in a modern lexerless way.
/// It is a recursive descent parser with one-pass over the input.
/// For the optimal implementation, I write this parser by hand without using any parser generator.
/// Zig is general purpose programming language for systems development, I need it to provide high-performance and maintainability.
const std = @import("std");

// The "living standard": https://html.spec.whatwg.org/
// current implementation is a very basic parser for educational purposes, it does not handle all edge cases
// it inherits the `non-normative` status of the "living standard"
// refer to: https://html.spec.whatwg.org/#element
const Element = struct {
    tagName: []const u8,
    // just for educational purposes, so I won't implement the NamedNodeMap, just an array of Attr
    attributes: ?[]const Attr = null,
    // refer to: https://dom.spec.whatwg.org/#dom-node-textcontent
    textContent: ?[]const u8 = null,
};
// refer to: https://dom.spec.whatwg.org/#attr
const Attr = struct {
    name: []const u8,
    value: ?[]const u8 = null,
};

pub fn parse(allocator: std.mem.Allocator, html: []const u8) ![]Element {
    var cursor: usize = 0;
    cursor = skipWhitespaceAndComments(html, cursor);
    var elements = try std.ArrayList(Element).initCapacity(allocator, 100);
    defer elements.deinit(allocator);

    // cursor is now at the first non-whitespace, non-comment character
    std.debug.print("\nparsing: \n\n", .{});
    while (cursor < html.len) {
        // detect the character sequence <!DOCTYPE html>
        if (cursor + 15 < html.len and html[cursor] == '<' and html[cursor + 1] == '!') {
            // Check for DOCTYPE case-insensitively
            var match = true;
            const doctype = "DOCTYPE";
            for (doctype, 0..) |expected_char, offset| {
                const actual_char = html[cursor + 2 + offset];
                if (std.ascii.toLower(actual_char) != std.ascii.toLower(expected_char)) {
                    match = false;
                    break;
                }
            }

            var html_match = true;
            if (match and html[cursor + 9] == ' ') {
                // Check for "html" case-insensitively
                const html_str = "html>";
                for (html_str, 0..) |expected_char, offset| {
                    const actual_char = html[cursor + 10 + offset];
                    if (std.ascii.toLower(actual_char) != std.ascii.toLower(expected_char)) {
                        html_match = false;
                        break;
                    }
                }

                if (html_match) {
                    cursor += 15;
                    continue;
                }
            } else {
                html_match = false;
            }

            if (match == false or html_match == false) return error.InvalidDOCTYPE;
        }
        cursor = skipWhitespaceAndComments(html, cursor);

        if (html[cursor] == '<' and cursor + 1 < html.len and html[cursor + 1] != '/') {
            const tag_name = peekTagName(html, cursor);
            if (tag_name == null) return error.InvalidTagName;
            cursor += (tag_name.?.len + 1);
            cursor = skipWhitespaceAndComments(html, cursor);
            const parsed_attrs = try parseAttributes(allocator, html, cursor);
            cursor = parsed_attrs.end_cursor;
            cursor = skipWhitespaceAndComments(html, cursor);
            if (html[cursor] == '/') cursor += 1;
            if (html[cursor] != '>') {
                return error.InvalidTag;
            } else {
                cursor += 1;
            }
            const textContent = passTextContent(html, cursor);

            const element = Element{ .tagName = tag_name.?, .attributes = parsed_attrs.attrs, .textContent = textContent };
            std.debug.print("Element: {s}\n", .{element.tagName});
            for (element.attributes.?) |attr| {
                if (attr.value.?.len > 0) {
                    std.debug.print("  Attribute: {s}='{s}'\n", .{ attr.name, attr.value.? });
                } else {
                    std.debug.print("  Attribute: {s}\n", .{attr.name});
                }
            }
            std.debug.print("  Text content: {s}\n", .{element.textContent.?});
            try elements.append(allocator, element);
        }
        cursor += 1;
    }

    return elements.toOwnedSlice(allocator);
}

fn peekTagName(html: []const u8, cursor: usize) ?[]const u8 {
    if (cursor >= html.len or html[cursor] != '<') return null;

    var current_cursor = cursor + 1;
    if (current_cursor >= html.len) return null;

    // Check if it's a closing tag
    const is_closing = html[current_cursor] == '/';
    if (is_closing) {
        current_cursor += 1;
    }

    // Find the end of tag name
    const start = current_cursor;
    while (current_cursor < html.len and
        html[current_cursor] != '>' and
        html[current_cursor] != '/' and
        html[current_cursor] != ' ' and
        html[current_cursor] != '\t' and
        html[current_cursor] != '\n' and
        html[current_cursor] != '\r')
    {
        current_cursor += 1;
    }

    if (start == current_cursor) return null;

    const tag_name = html[start..current_cursor];
    return tag_name;
}

fn passTextContent(html: []const u8, cursor: usize) []const u8 {
    var current_cursor = cursor;

    // Find the start of text content (skip whitespace)
    while (current_cursor < html.len and
        (html[current_cursor] == ' ' or
            html[current_cursor] == '\t' or
            html[current_cursor] == '\n' or
            html[current_cursor] == '\r'))
    {
        current_cursor += 1;
    }

    const start = current_cursor;

    // Find the end of text content (until we hit a '<')
    while (current_cursor < html.len and html[current_cursor] != '<') {
        current_cursor += 1;
    }

    // Trim trailing whitespace from text content
    var end = current_cursor;
    while (end > start and
        (html[end - 1] == ' ' or
            html[end - 1] == '\t' or
            html[end - 1] == '\n' or
            html[end - 1] == '\r'))
    {
        end -= 1;
    }

    return html[start..end];
}

fn parseAttributes(allocator: std.mem.Allocator, html: []const u8, cursor: usize) !struct { attrs: []const Attr, end_cursor: usize } {
    var current_cursor = cursor;
    var attrs = try std.ArrayList(Attr).initCapacity(
        allocator,
        10,
    );
    defer attrs.deinit(allocator);

    // Skip past the opening tag name and whitespace
    while (current_cursor < html.len and html[current_cursor] != '>') {
        // Skip whitespace
        if (std.ascii.isWhitespace(html[current_cursor])) {
            current_cursor += 1;
            continue;
        }

        // Check for self-closing tag
        if (current_cursor + 1 < html.len and
            html[current_cursor] == '/' and
            html[current_cursor + 1] == '>')
        {
            break;
        }

        // Parse attribute name
        const name_start = current_cursor;
        while (current_cursor < html.len and
            html[current_cursor] != '=' and
            html[current_cursor] != '>' and
            html[current_cursor] != '/' and
            !std.ascii.isWhitespace(html[current_cursor]))
        {
            current_cursor += 1;
        }

        if (current_cursor == name_start) {
            // No attribute name found, skip to next character
            current_cursor += 1;
            continue;
        }

        const attr_name = html[name_start..current_cursor];

        // Skip whitespace before '='
        while (current_cursor < html.len and std.ascii.isWhitespace(html[current_cursor])) {
            current_cursor += 1;
        }

        // Check for '='
        if (current_cursor < html.len and html[current_cursor] == '=') {
            current_cursor += 1;

            // Skip whitespace after '='
            while (current_cursor < html.len and std.ascii.isWhitespace(html[current_cursor])) {
                current_cursor += 1;
            }

            // Parse attribute value
            var attr_value: []const u8 = "";
            if (current_cursor < html.len) {
                const quote_char = html[current_cursor];
                if (quote_char == '"' or quote_char == '\'') {
                    // Quoted attribute value
                    current_cursor += 1;
                    const value_start = current_cursor;
                    while (current_cursor < html.len and html[current_cursor] != quote_char) {
                        current_cursor += 1;
                    }
                    attr_value = html[value_start..current_cursor];
                    if (current_cursor < html.len) {
                        current_cursor += 1; // Skip closing quote
                    }
                } else {
                    // Unquoted attribute value
                    const value_start = current_cursor;
                    while (current_cursor < html.len and
                        html[current_cursor] != '>' and
                        html[current_cursor] != '/' and
                        !std.ascii.isWhitespace(html[current_cursor]))
                    {
                        current_cursor += 1;
                    }
                    attr_value = html[value_start..current_cursor];
                }
            }

            try attrs.append(allocator, Attr{
                .name = attr_name,
                .value = attr_value,
            });
        } else {
            // Attribute without value (boolean attribute)
            try attrs.append(allocator, Attr{ .name = attr_name });
        }
    }

    return .{ .attrs = try attrs.toOwnedSlice(allocator), .end_cursor = current_cursor };
}

fn skipWhitespaceAndComments(html: []const u8, cursor: usize) usize {
    var current_cursor = cursor;

    while (current_cursor < html.len) {
        const c = html[current_cursor];

        // Skip whitespace
        if (std.ascii.isWhitespace(c)) {
            current_cursor += 1;
            continue;
        }

        // Skip HTML comments <!-- ... -->
        if (current_cursor + 3 < html.len and
            html[current_cursor] == '<' and
            html[current_cursor + 1] == '!' and
            html[current_cursor + 2] == '-' and
            html[current_cursor + 3] == '-')
        {
            current_cursor += 4;
            // Find the end of comment -->
            while (current_cursor + 2 < html.len) {
                if (html[current_cursor] == '-' and
                    html[current_cursor + 1] == '-' and
                    html[current_cursor + 2] == '>')
                {
                    current_cursor += 3; // Skip past -->
                    break;
                }
                current_cursor += 1;
            }
            continue;
        }

        // If we found non-whitespace, non-comment content, break
        break;
    }

    return current_cursor;
}

test "html_parse" {
    // use multiline string for better readability
    const html =
        \\<!-- this is comment -->
        \\                  
        \\<!DOCTYPE html>
        \\<html lang="en">
        \\  <head>
        \\      <meta charset="UTF-8">
        \\      <meta name="viewport" content="width=device-width, initial-scale=1.0">
        \\      <title>Document</title>
        \\      <!-- Add your styles here, let me assume you have a main.css file -->
        \\      <link rel="stylesheet" href="./main.css">
        \\  </head>
        \\  <body>
        \\      <h1>Hello, World!</h1>
        \\      <div id="app" />
        \\      <script type="module" src="./main.tsx"></script>
        \\  </body>
        \\</html>
    ;
    const result = try parse(std.testing.allocator, html);
    defer {
        for (result) |element| {
            if (element.attributes) |attributes| {
                std.testing.allocator.free(attributes);
            }
        }
        std.testing.allocator.free(result);
    }
}
