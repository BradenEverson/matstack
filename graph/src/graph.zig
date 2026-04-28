//! The core computation graph architecture

const std = @import("std");
const Allocator = std.mem.Allocator;

const Node = @import("node.zig");

nodes: std.ArrayList(Node) = .empty,

test {
    _ = @import("node.zig");
}
