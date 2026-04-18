const std = @import("std");

pub fn main() !void {
    std.debug.print("The Compiler Part\n", .{});
}

test {
    _ = @import("tokenizer.zig");
    _ = @import("parser.zig");
}
