//! The Tokenizer

const std = @import("std");

const TokenizeError = error{
    UnexpectedEOF,
    UnexpectedCharacter,
};

pub const TokenTag = enum {
    keyword,
    ident,

    plus,
    minus,
    at,
    star,
    slash,
    equals,
    bang,
    newline,
    number,
    eof,
};

pub const Token = struct {
    tag: TokenTag,
    line: usize,
    col: usize,
    data: []const u8,
};

pub fn tokenize(stream: []const u8, tokens: *std.ArrayList(Token), alloc: std.mem.Allocator) !void {
    var idx: usize = 0;
    var line: usize = 1;
    var col: usize = 1;

    var curr: ?Token = undefined;

    while (idx < stream.len) {
        curr = null;

        const start_idx = idx;
        const start_col = col;

        switch (stream[idx]) {
            'a'...'z', 'A'...'Z', '_' => {
                while (idx < stream.len and (std.ascii.isAlphanumeric(stream[idx]) or stream[idx] == '_')) {
                    idx += 1;
                    col += 1;
                }
                const ident = stream[start_idx..idx];
                // TODO: Check if ident or keyword
                curr = Token{
                    .tag = .ident,
                    .line = line,
                    .col = start_col,
                    .data = ident,
                };
            },

            '0'...'9' => {
                while (idx < stream.len and (std.ascii.isDigit(stream[idx]) or stream[idx] == '.')) {
                    idx += 1;
                    col += 1;
                }
                const number = stream[start_idx..idx];
                curr = Token{
                    .tag = .number,
                    .line = line,
                    .col = start_col,
                    .data = number,
                };
            },
            '*' => {
                idx += 1;
                col += 1;
                curr = Token{
                    .tag = .star,
                    .line = line,
                    .col = start_col,
                    .data = stream[start_idx..idx],
                };
            },
            '/' => {
                idx += 1;
                col += 1;
                curr = Token{
                    .tag = .slash,
                    .line = line,
                    .col = start_col,
                    .data = stream[start_idx..idx],
                };
            },
            '+' => {
                idx += 1;
                col += 1;
                curr = Token{
                    .tag = .plus,
                    .line = line,
                    .col = start_col,
                    .data = stream[start_idx..idx],
                };
            },
            '-' => {
                idx += 1;
                col += 1;
                curr = Token{
                    .tag = .minus,
                    .line = line,
                    .col = start_col,
                    .data = stream[start_idx..idx],
                };
            },
            '=' => {
                idx += 1;
                col += 1;
                curr = Token{
                    .tag = .equals,
                    .line = line,
                    .col = start_col,
                    .data = stream[start_idx..idx],
                };
            },
            ';' => {
                idx += 1;
                col += 1;
                curr = Token{
                    .tag = .newline,
                    .line = line,
                    .col = start_col,
                    .data = stream[start_idx..idx],
                };
                line += 1;
            },
            ' ', '\t' => {
                while (idx < stream.len and (stream[idx] == ' ' or stream[idx] == '\t')) {
                    idx += 1;
                    col += 1;
                }
            },
            '\r' => {
                idx += 1;
                if (idx < stream.len and stream[idx] == '\n') {
                    idx += 1;
                }
                line += 1;
                col = 1;
            },
            else => {
                std.debug.print("Unexpected character: '{c}' at line {}, col {}\n", .{ stream[idx], line, col });

                return TokenizeError.UnexpectedCharacter;
            },
        }

        if (curr) |tok| {
            try tokens.append(alloc, tok);
        }
    }

    try tokens.append(alloc, .{ .col = col, .line = line, .tag = .eof, .data = undefined });
}

test "basic tokenize" {
    const alloc = std.testing.allocator;
    var tokens = std.ArrayList(Token).empty;
    defer tokens.deinit(alloc);

    const simple = "b = 10";

    try tokenize(simple, &tokens, alloc);

    try std.testing.expectEqual(tokens.items[0].tag, .ident);
    try std.testing.expectEqualSlices(u8, tokens.items[0].data, "b");

    try std.testing.expectEqual(tokens.items[1].tag, .equals);

    try std.testing.expectEqual(tokens.items[2].tag, .number);
    try std.testing.expectEqualSlices(u8, tokens.items[2].data, "10");

    try std.testing.expectEqual(tokens.items[3].tag, .eof);
}
