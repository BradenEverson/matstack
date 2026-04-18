const std = @import("std");

const tokenizer = @import("tokenizer.zig");
const Token = tokenizer.Token;

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
    std.debug.print("{s}\n", .{source});

    var tokens: std.ArrayList(Token) = .empty;
    defer tokens.deinit(alloc);

    try tokenizer.tokenize(source, &tokens, alloc);

    for (tokens.items) |tok| {
        std.debug.print("{} - {s}\n", .{ tok.tag, tok.data });
    }
}

test {
    _ = @import("tokenizer.zig");
    _ = @import("parser.zig");
}
