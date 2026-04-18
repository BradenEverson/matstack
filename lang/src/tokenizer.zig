//! The Tokenizer

const std = @import("std");

const TokenizeError = error{
    UnexpectedEOF,
    UnexpectedCharacter,
};

pub const Keyword = enum {
    tensor,
    rand,
    debug,
    softmax,
    relu,
    cross_entropy,
};
pub const KeywordLookup = std.StaticStringMap(Keyword).initComptime(.{
    .{ "tensor", .tensor },
    .{ "rand", .rand },
    .{ "debug", .debug },
    .{ "softmax", .softmax },
    .{ "relu", .relu },
    .{ "cross_entropy", .cross_entropy },
});

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
    open_bracket,
    open_paren,
    close_bracket,
    close_paren,
    comma,
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

                const tag: TokenTag = if (KeywordLookup.get(ident)) |_|
                    .keyword
                else
                    .ident;

                curr = Token{
                    .tag = tag,
                    .line = line,
                    .col = start_col,
                    .data = ident,
                };
            },

            '0'...'9' => {
                var seen_dot = false;
                while (idx < stream.len and (std.ascii.isDigit(stream[idx]) or (stream[idx] == '.' and !seen_dot))) {
                    if (stream[idx] == '.')
                        seen_dot = true;

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

            ',' => {
                idx += 1;
                col += 1;
                curr = Token{
                    .tag = .comma,
                    .line = line,
                    .col = start_col,
                    .data = stream[start_idx..idx],
                };
            },

            '(' => {
                idx += 1;
                col += 1;
                curr = Token{
                    .tag = .open_paren,
                    .line = line,
                    .col = start_col,
                    .data = stream[start_idx..idx],
                };
            },

            ')' => {
                idx += 1;
                col += 1;
                curr = Token{
                    .tag = .close_paren,
                    .line = line,
                    .col = start_col,
                    .data = stream[start_idx..idx],
                };
            },

            '[' => {
                idx += 1;
                col += 1;
                curr = Token{
                    .tag = .open_bracket,
                    .line = line,
                    .col = start_col,
                    .data = stream[start_idx..idx],
                };
            },

            ']' => {
                idx += 1;
                col += 1;
                curr = Token{
                    .tag = .close_bracket,
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

test "tokenize tensor initialization" {
    const alloc = std.testing.allocator;
    var tokens = std.ArrayList(Token).empty;
    defer tokens.deinit(alloc);

    const simple = "W = tensor([[1,2,3],[4,5,6]])";

    try tokenize(simple, &tokens, alloc);

    const expected = &[_]TokenTag{
        .ident,
        .equals,
        .keyword,
        .open_paren,
        .open_bracket,
        .open_bracket,
        .number,
        .comma,
        .number,
        .comma,
        .number,
        .close_bracket,
        .comma,
        .open_bracket,
        .number,
        .comma,
        .number,
        .comma,
        .number,
        .close_bracket,
        .close_bracket,
        .close_paren,
        .eof,
    };

    for (expected, 0..) |expected_tag, i| {
        const seen_tag = tokens.items[i].tag;
        try std.testing.expectEqual(expected_tag, seen_tag);
    }
}
