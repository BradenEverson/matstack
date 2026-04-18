//! The Tokenizer

const std = @import("std");

const TokenizeError = error{
    UnexpectedEOF,
    UnexpectedCharacter,
};

pub const Keyword = enum {
    zeros_like,
    tensor,
    rand,
    debug,
    softmax,
    relu,
    cross_entropy,
    ln,
    exp,
};

pub const KeywordLookup = std.StaticStringMap(Keyword).initComptime(.{
    .{ "zeros_like", .zeros_like },
    .{ "tensor", .tensor },
    .{ "rand", .rand },
    .{ "debug", .debug },
    .{ "softmax", .softmax },
    .{ "relu", .relu },
    .{ "cross_entropy", .cross_entropy },
    .{ "ln", .ln },
    .{ "exp", .exp },
});

pub const TokenTag = enum {
    keyword,
    ident,
    number,

    plus,
    minus,
    at,
    star,
    slash,
    equals,
    bang,
    newline,
    eof,
    open_bracket,
    open_paren,
    close_bracket,
    close_paren,
    comma,
};

pub const TokenLookup = std.StaticStringMap(TokenTag).initComptime(.{
    .{ "+", .plus },
    .{ "-", .minus },
    .{ "@", .at },
    .{ "*", .star },
    .{ "/", .slash },
    .{ "=", .equals },
    .{ "!", .bang },
    .{ "[", .open_bracket },
    .{ "(", .open_paren },
    .{ "]", .close_bracket },
    .{ ")", .close_paren },
    .{ ",", .comma },
});

pub const Token = struct {
    tag: TokenTag,
    line: usize,
    col: usize,
    data: []const u8 = "no data",
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

        if (TokenLookup.get(stream[idx .. idx + 1])) |tag| {
            idx += 1;
            col += 1;
            curr = Token{
                .tag = tag,
                .line = line,
                .col = start_col,
                .data = stream[start_idx..idx],
            };
        } else switch (stream[idx]) {
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

            ' ', '\t', '\r' => {
                while (idx < stream.len and (stream[idx] == ' ' or stream[idx] == '\t')) {
                    idx += 1;
                    col += 1;
                }
            },

            '\n' => {
                idx += 1;
                line += 1;
                col = 1;

                curr = Token{
                    .tag = .newline,
                    .line = line,
                    .col = start_col,
                    .data = stream[start_idx..idx],
                };
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

    try tokens.append(alloc, .{ .col = col, .line = line, .tag = .eof });
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
