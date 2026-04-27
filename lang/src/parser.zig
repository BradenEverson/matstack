//! The Parser Hooray!

const std = @import("std");

const tokenizer = @import("tokenizer.zig");
const Token = tokenizer.Token;
const TokenTag = tokenizer.TokenTag;

pub const Expr = union(enum) {
    assignment: struct { name: []const u8, val: *const Expr },
    binary_op: struct { left: *const Expr, op: BinaryOp, right: *const Expr },
    unary_op: struct { op: tokenizer.Keyword, expr: *const Expr },
    loop: struct {
        counter: []const u8,
        from: isize,
        to: isize,
        eval: std.ArrayList(*const Expr) = .empty,
    },
    literal: Literal,
    rand_tensor: std.ArrayList(usize),
    load: []const u8,
    save: struct { name: u8, on: *const Expr },
    variable: []const u8,
    slice: struct { on: *const Expr, slice: *const Expr },
};

pub const Literal = union(enum) {
    number: f32,
    multidim: std.ArrayList(*const Expr),
};

pub const BinaryOp = enum {
    gt,
    lt,
    add,
    sub,
    mul,
    div,
    matmul,
    pow,
    cross_entropy,
};

pub const ParserError = error{
    UnexpectedToken,
    UnexpectedKeywordHere,
    ExpectedSemicolon,
    OutOfTokens,
};

const AnyParserError = ParserError || std.mem.Allocator.Error || std.fmt.ParseFloatError || std.fmt.ParseIntError;

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

    fn peekTok(self: *const Parser) Token {
        if (self.cursor >= self.tokens.len) {
            return .{ .tag = .eof };
        }
        return self.tokens[self.cursor];
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

    pub fn parse(self: *Parser, ast: *std.ArrayList(*const Expr)) AnyParserError!void {
        while (!self.at_end()) {
            while (self.peek() == .newline) {
                try self.consume(.newline);
            }

            const expr = try self.statement();
            try ast.append(self.arena.allocator(), expr);

            while (self.peek() == .newline) {
                try self.consume(.newline);
            }
        }
    }

    pub fn statement(self: *Parser) AnyParserError!*const Expr {
        if (self.peek() == .keyword) {
            const kw = tokenizer.KeywordLookup.get(self.tokens[self.cursor].data).?;
            if (kw == .for_kw) {
                // Parse a for loop
                try self.consume(.keyword);
                try self.consume(.open_paren);

                // loop variable
                const identifier = self.tokens[self.cursor].data;
                try self.consume(.ident);

                // in
                // TODO: make this more restrictive. Technically right now
                // it could be *any* keyword (for (i relu 0..5) would be valid lol)
                try self.consume(.keyword);

                // parse the range
                const bottom = self.tokens[self.cursor].data;
                try self.consume(.number);
                const bottom_num: isize = try std.fmt.parseInt(isize, bottom, 10);

                // cute lil arrow
                try self.consume(.minus);
                try self.consume(.gt);

                const top = self.tokens[self.cursor].data;
                try self.consume(.number);
                const top_num: isize = try std.fmt.parseInt(isize, top, 10);

                try self.consume(.close_paren);

                const expr = try self.arena.allocator().create(Expr);
                expr.* = .{ .loop = .{
                    .counter = identifier,
                    .from = bottom_num,
                    .to = top_num,
                } };

                try self.consume(.open_brace);

                while (self.peek() == .newline) {
                    try self.consume(.newline);
                }

                // read the block
                while (self.peek() != .close_brace) {
                    const s = try self.statement();
                    try expr.loop.eval.append(self.arena.allocator(), s);

                    while (self.peek() == .newline) {
                        try self.consume(.newline);
                    }
                }

                try self.consume(.close_brace);

                return expr;
            }
        }

        const expr = try self.expression();
        return expr;
    }

    pub fn expression(self: *Parser) AnyParserError!*const Expr {
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
        var left = try self.comparison();

        while (self.peek() == .plus or self.peek() == .minus) {
            const op_token = self.tokens[self.cursor];
            self.advance();
            const right = try self.comparison();

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

    fn comparison(self: *Parser) AnyParserError!*const Expr {
        var left = try self.factor();

        while (self.peek() == .gt or self.peek() == .lt) {
            const op_token = self.tokens[self.cursor];
            self.advance();
            const right = try self.factor();

            const op = switch (op_token.tag) {
                .gt => BinaryOp.gt,
                .lt => BinaryOp.lt,
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

    fn factor(self: *Parser) AnyParserError!*const Expr {
        var left = try self.power();

        while (self.peek() == .star or self.peek() == .slash or self.peek() == .at) {
            const op_token = self.tokens[self.cursor];
            self.advance();
            const right = try self.power();

            const op = switch (op_token.tag) {
                .star => BinaryOp.mul,
                .slash => BinaryOp.div,
                .at => BinaryOp.matmul,
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

    fn power(self: *Parser) AnyParserError!*const Expr {
        var left = try self.primary();

        while (self.peek() == .caret) {
            const op_token = self.tokens[self.cursor];
            self.advance();
            const right = try self.primary();

            const op = switch (op_token.tag) {
                .caret => BinaryOp.pow,
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

    fn primary(self: *Parser) AnyParserError!*const Expr {
        const current_token = self.tokens[self.cursor];
        var expr: *const Expr = undefined;

        switch (current_token.tag) {
            .ident => {
                const variable_expr = try self.arena.allocator().create(Expr);
                variable_expr.* = .{ .variable = current_token.data };
                self.advance();
                expr = variable_expr;
            },

            .keyword => {
                const kw = tokenizer.KeywordLookup.get(current_token.data).?;
                self.advance();

                switch (kw) {
                    .for_kw, .in => return error.UnexpectedKeywordHere,
                    .rand => {
                        // parse out the shape of the random tensor
                        const rand_tensor = try self.arena.allocator().create(Expr);
                        rand_tensor.* = .{ .rand_tensor = .empty };

                        try self.consume(.open_paren);

                        while (self.peek() != .close_paren) {
                            const dim = self.peekTok();
                            try self.consume(.number);

                            const dim_usize = try std.fmt.parseInt(usize, dim.data, 10);
                            try rand_tensor.rand_tensor.append(self.arena.allocator(), dim_usize);

                            if (self.peek() != .close_paren)
                                try self.consume(.comma);
                        }

                        try self.consume(.close_paren);
                        return rand_tensor;
                    },
                    .load => {
                        const load_tensor = try self.arena.allocator().create(Expr);

                        try self.consume(.open_paren);

                        const tok = self.tokens[self.cursor];
                        load_tensor.* = .{ .load = tok.data };
                        try self.consume(.string);

                        try self.consume(.close_paren);

                        return load_tensor;
                    },
                    .save => {
                        const save_tensor = try self.arena.allocator().create(Expr);

                        try self.consume(.open_paren);

                        const name = self.tokens[self.cursor];
                        try self.consume(.string);
                        try self.consume(.comma);

                        const on = try self.term();
                        try self.consume(.close_paren);

                        save_tensor.* = .{
                            .save = .{
                                .name = name.data[0],
                                .on = on,
                            },
                        };

                        return save_tensor;
                    },
                    .cross_entropy => {
                        try self.consume(.open_paren);
                        const p = try self.term();
                        try self.consume(.comma);
                        const y = try self.term();
                        try self.consume(.close_paren);

                        const binary_expr = try self.arena.allocator().create(Expr);
                        binary_expr.* = .{ .binary_op = .{ .op = .cross_entropy, .left = p, .right = y } };

                        return binary_expr;
                    },

                    else => {
                        try self.consume(.open_paren);
                        const on = try self.term();
                        try self.consume(.close_paren);

                        const unary_expr = try self.arena.allocator().create(Expr);
                        unary_expr.* = .{ .unary_op = .{ .op = kw, .expr = on } };

                        return unary_expr;
                    },
                }
            },

            .open_paren => {
                self.advance();
                const inner = try self.term();
                try self.consume(.close_paren);
                expr = inner;
            },

            else => {
                expr = try self.literal();
            },
        }

        if (self.peek() == .open_bracket) {
            try self.consume(.open_bracket);
            const slice = try self.expression();
            try self.consume(.close_bracket);

            const slice_expr = try self.arena.allocator().create(Expr);
            slice_expr.* = .{ .slice = .{ .on = expr, .slice = slice } };
            return slice_expr;
        }

        return expr;
    }

    fn literal(self: *Parser) AnyParserError!*const Expr {
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

            .minus => {
                const next_token = self.tokens[self.cursor];
                self.advance();

                const number_val = try std.fmt.parseFloat(f32, next_token.data);
                const literal_expr = try self.arena.allocator().create(Expr);
                literal_expr.* = .{ .literal = .{ .number = -1 * number_val } };
                return literal_expr;
            },

            .number => {
                const number_val = try std.fmt.parseFloat(f32, current_token.data);
                const literal_expr = try self.arena.allocator().create(Expr);
                literal_expr.* = .{ .literal = .{ .number = number_val } };
                return literal_expr;
            },
            else => {
                return ParserError.UnexpectedToken;
            },
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
        .{ .tag = .minus },
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
    try std.testing.expectEqual(row3[2].literal.number, -9);
}

test "keyword 'function' eval" {
    const alloc = std.testing.allocator;
    const tokens: []const Token = &[_]Token{
        .{ .tag = .keyword, .data = "relu" },
        .{ .tag = .open_paren },
        .{ .tag = .ident, .data = "y" },
        .{ .tag = .close_paren },
    };

    var p = Parser.init(alloc, tokens);
    defer p.deinit();

    var ast: std.ArrayList(*const Expr) = .empty;
    try p.parse(&ast);

    try std.testing.expectEqual(ast.items[0].unary_op.op, .relu);
    try std.testing.expectEqualStrings(ast.items[0].unary_op.expr.variable, "y");
}
