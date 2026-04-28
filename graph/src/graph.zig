//! The core computation graph architecture

const std = @import("std");
const Allocator = std.mem.Allocator;
const Tensor = @import("matstack").tensor;

const Node = @import("node.zig");

nodes: std.ArrayList(Node) = .empty,
inputs: std.ArrayList(?Tensor) = .empty,
outputs: std.ArrayList(Node) = .empty,

const Graph = @This();

pub fn loadInput(graph: *Graph, idx: usize, val: Tensor) void {
    graph.inputs.items[idx] = val;
}

test {
    _ = @import("node.zig");
}
