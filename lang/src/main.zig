const std = @import("std");

const tokenizer = @import("tokenizer.zig");
const Token = tokenizer.Token;

const parse = @import("parser.zig");
const Parser = parse.Parser;

const compiler = @import("compiler.zig");
const VmIr = compiler.VmIR;

pub fn main(init: std.process.Init) !void {
    const arena = init.arena;
    const io = init.io;

    const alloc = arena.allocator();

    var args = init.minimal.args.iterate();
    _ = args.next();

    var source: []u8 = undefined;

    if (args.next()) |file_path| {
        source = try std.Io.Dir.cwd().readFileAlloc(
            io,
            file_path,
            alloc,
            .unlimited,
        );
    } else {
        std.debug.print("Missing source code!!!\n", .{});
        std.process.exit(1);
    }

    errdefer alloc.free(source);

    var tokens: std.ArrayList(Token) = .empty;
    defer tokens.deinit(alloc);

    try tokenizer.tokenize(source, &tokens, alloc);

    var parser = Parser.init(alloc, tokens.items);
    defer parser.deinit();

    var ast: std.ArrayList(*const parse.Expr) = .empty;
    try parser.parse(&ast);

    var vmir: VmIr = .{};
    defer vmir.deinit(alloc);

    try vmir.fromAst(alloc, ast.items);

    for (vmir.tensors.items) |tensor| {
        std.debug.print("{any}\n", .{tensor});
    }

    for (vmir.instructions.items) |instr| {
        std.debug.print("{} - {}\n", .{ instr.cmd, instr.extra });
    }
}

test {
    _ = @import("tokenizer.zig");
    _ = @import("parser.zig");
    _ = @import("compiler.zig");
}
