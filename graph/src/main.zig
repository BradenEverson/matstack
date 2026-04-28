const std = @import("std");

pub fn main(init: std.process.Init) !void {
    _ = init;
}

test {
    _ = @import("graph.zig");
}
