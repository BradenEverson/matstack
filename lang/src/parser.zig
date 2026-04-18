//! The Parser Hooray!

const std = @import("std");

const tokenizer = @import("tokenizer.zig");
const Token = tokenizer.Token;
const TokenTag = tokenizer.TokenTag;

pub const Expr = union(enum) {
    assignment: struct { name: []const u8, val: *const Expr },
    binary_op: struct { left: *const Expr, op: BinaryOp, right: *const Expr },
    unary_op: struct { op: UnaryOp, expr: *const Expr },
    literal: Literal,
    variable: []const u8,
};

pub const Literal = union(enum) {
    number: f32,
    multidim: std.ArrayList(*const Expr),
};

pub const BinaryOp = enum {
    add,
    sub,
    mul,
    div,
    matmul,
};

pub const UnaryOp = enum {
    relu,
    softmax,
    cross_entropy,
    ln,
    exp,
};

pub const ParserError = error{
    UnexpectedToken,
    ExpectedSemicolon,
    OutOfTokens,
    TODO,
};

pub const Parser = struct {
    tokens: []const Token,
    cursor: usize,
    arena: std.heap.ArenaAllocator,

    pub fn init(alloc: std.mem.Allocator, tokens: []const Token) Parser {
        return Parser{
            .arena = std.heap.ArenaAllocator.init(alloc),
            .tokens = tokens,
            .cursor = 0,
        };
    }

    pub fn deinit(self: *Parser) void {
        self.arena.deinit();
    }

    fn peek(self: *const Parser) TokenTag {
        if (self.cursor >= self.tokens.len) {
            return .eof;
        }
        return self.tokens[self.cursor].tag;
    }

    fn peek_n(self: *const Parser, n: comptime_int) TokenTag {
        if (self.cursor + n >= self.tokens.len) {
            return .eof;
        }
        return self.tokens[self.cursor + n].tag;
    }

    fn advance(self: *Parser) void {
        if (self.cursor < self.tokens.len) {
            self.cursor += 1;
        }
    }

    fn consume(self: *Parser, tok: TokenTag) ParserError!void {
        if (self.peek() == tok) {
            self.advance();
            return;
        } else {
            return ParserError.UnexpectedToken;
        }
    }

    fn at_end(self: *Parser) bool {
        return self.peek() == .eof;
    }

    pub fn parse(self: *Parser, ast: *std.ArrayList(*const Expr)) !void {
        while (!self.at_end()) {
            const expr = try self.statement();
            try ast.append(self.arena.allocator(), expr);

            while (self.peek() == .newline) {
                try self.consume(.newline);
            }
        }
    }

    pub fn statement(self: *Parser) !*const Expr {
        const expr = try self.expression();
        return expr;
    }

    pub fn expression(self: *Parser) !*const Expr {
        if (self.peek() == .ident and self.peek_n(1) == .equals) {
            const name = self.tokens[self.cursor].data;
            self.advance();
            self.advance();

            const val = try self.expression();

            const assignment_expr = try self.arena.allocator().create(Expr);
            assignment_expr.* = .{
                .assignment = .{
                    .name = name,
                    .val = val,
                },
            };
            return assignment_expr;
        }

        return self.term();
    }

    fn term(self: *Parser) !*const Expr {
        var left = try self.factor();

        while (self.peek() == .plus or self.peek() == .minus) {
            const op_token = self.tokens[self.cursor];
            self.advance();
            const right = try self.factor();

            const op = switch (op_token.tag) {
                .plus => BinaryOp.add,
                .minus => BinaryOp.sub,
                else => unreachable,
            };

            const binary_op_expr = try self.arena.allocator().create(Expr);
            binary_op_expr.* = .{
                .binary_op = .{
                    .left = left,
                    .op = op,
                    .right = right,
                },
            };
            left = binary_op_expr;
        }

        return left;
    }

    fn factor(self: *Parser) !*const Expr {
        var left = try self.primary();

        while (self.peek() == .star or self.peek() == .slash) {
            const op_token = self.tokens[self.cursor];
            self.advance();
            const right = try self.primary();

            const op = switch (op_token.tag) {
                .star => BinaryOp.mul,
                .slash => BinaryOp.div,
                else => unreachable,
            };

            const binary_op_expr = try self.arena.allocator().create(Expr);
            binary_op_expr.* = .{
                .binary_op = .{
                    .left = left,
                    .op = op,
                    .right = right,
                },
            };
            left = binary_op_expr;
        }

        return left;
    }

    fn primary(self: *Parser) !*const Expr {
        const current_token = self.tokens[self.cursor];

        switch (current_token.tag) {
            .ident => {
                const variable_expr = try self.arena.allocator().create(Expr);
                variable_expr.* = .{ .variable = current_token.data };
                self.advance();
                return variable_expr;
            },
            else => return try self.literal(),
        }
    }

    fn literal(self: *Parser) !*const Expr {
        const current_token = self.tokens[self.cursor];
        self.advance();

        switch (current_token.tag) {
            .open_bracket => {
                const literal_expr = try self.arena.allocator().create(Expr);
                literal_expr.* = .{ .literal = .{ .multidim = .empty } };
                while (self.peek() != .close_bracket) {
                    const subliteral_expr = try self.literal();

                    try literal_expr.literal.multidim.append(
                        self.arena.allocator(),
                        subliteral_expr,
                    );

                    if (self.peek() != .close_bracket)
                        try self.consume(.comma);
                }

                try self.consume(.close_bracket);
                return literal_expr;
            },

            .number => {
                const number_val = try std.fmt.parseFloat(f32, current_token.data);
                const literal_expr = try self.arena.allocator().create(Expr);
                literal_expr.* = .{ .literal = .{ .number = number_val } };
                return literal_expr;
            },
            else => return ParserError.UnexpectedToken,
        }
    }
};

test "create a parser" {
    const alloc = std.testing.allocator;
    const tokens: [0]Token = .{};

    var p = Parser.init(alloc, &tokens);
    defer p.deinit();

    try std.testing.expectEqual(0, p.cursor);
}

test "basic parse" {
    const alloc = std.testing.allocator;
    const tokens: []const Token = &[_]Token{
        .{ .tag = .ident, .data = "W" },
        .{ .tag = .equals },
        .{ .tag = .number, .data = "1.5" },
        .{ .tag = .newline },
    };

    var p = Parser.init(alloc, tokens);
    defer p.deinit();

    var ast: std.ArrayList(*const Expr) = .empty;
    try p.parse(&ast);

    try std.testing.expectEqualStrings(ast.items[0].assignment.name, "W");
    try std.testing.expectEqual(ast.items[0].assignment.val.literal.number, 1.5);
}

test "basic vector" {
    const alloc = std.testing.allocator;
    const tokens: []const Token = &[_]Token{
        .{ .tag = .ident, .data = "W" },
        .{ .tag = .equals },

        .{ .tag = .open_bracket },

        .{ .tag = .number, .data = "1" },
        .{ .tag = .comma },

        .{ .tag = .number, .data = "2" },
        .{ .tag = .comma },

        .{ .tag = .number, .data = "3" },
        .{ .tag = .comma },

        .{ .tag = .close_bracket },

        .{ .tag = .newline },
    };

    var p = Parser.init(alloc, tokens);
    defer p.deinit();

    var ast: std.ArrayList(*const Expr) = .empty;
    try p.parse(&ast);

    const vector_res = ast.items[0].assignment.val.literal.multidim.items;

    try std.testing.expectEqual(vector_res[0].literal.number, 1);
    try std.testing.expectEqual(vector_res[1].literal.number, 2);
    try std.testing.expectEqual(vector_res[2].literal.number, 3);
}

test "basic matrix" {
    const alloc = std.testing.allocator;
    const tokens: []const Token = &[_]Token{
        .{ .tag = .ident, .data = "W" },
        .{ .tag = .equals },
        .{ .tag = .open_bracket },
        .{ .tag = .open_bracket },
        .{ .tag = .number, .data = "1" },
        .{ .tag = .comma },
        .{ .tag = .number, .data = "2" },
        .{ .tag = .comma },
        .{ .tag = .number, .data = "3" },
        .{ .tag = .close_bracket },
        .{ .tag = .comma },
        .{ .tag = .open_bracket },
        .{ .tag = .number, .data = "4" },
        .{ .tag = .comma },
        .{ .tag = .number, .data = "5" },
        .{ .tag = .comma },
        .{ .tag = .number, .data = "6" },
        .{ .tag = .close_bracket },
        .{ .tag = .comma },
        .{ .tag = .open_bracket },
        .{ .tag = .number, .data = "7" },
        .{ .tag = .comma },
        .{ .tag = .number, .data = "8" },
        .{ .tag = .comma },
        .{ .tag = .number, .data = "9" },
        .{ .tag = .close_bracket },
        .{ .tag = .close_bracket },
        .{ .tag = .newline },
    };

    var p = Parser.init(alloc, tokens);
    defer p.deinit();

    var ast: std.ArrayList(*const Expr) = .empty;
    try p.parse(&ast);

    const matrix = ast.items[0].assignment.val.literal.multidim.items;
    const row1 = matrix[0].literal.multidim.items;
    const row2 = matrix[1].literal.multidim.items;
    const row3 = matrix[2].literal.multidim.items;

    try std.testing.expectEqual(row1[0].literal.number, 1);
    try std.testing.expectEqual(row1[1].literal.number, 2);
    try std.testing.expectEqual(row1[2].literal.number, 3);

    try std.testing.expectEqual(row2[0].literal.number, 4);
    try std.testing.expectEqual(row2[1].literal.number, 5);
    try std.testing.expectEqual(row2[2].literal.number, 6);

    try std.testing.expectEqual(row3[0].literal.number, 7);
    try std.testing.expectEqual(row3[1].literal.number, 8);
    try std.testing.expectEqual(row3[2].literal.number, 9);
}
