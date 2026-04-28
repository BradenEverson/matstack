//! The core computation graph architecture

const std = @import("std");
const Allocator = std.mem.Allocator;
const Tensor = @import("matstack").Tensor;

const Node = @import("node.zig");
const NodeId = Node.NodeId;

nodes: std.ArrayList(Node) = .empty,
inputs: std.ArrayList(?Tensor) = .empty,
outputs: std.ArrayList(Node) = .empty,

const Graph = @This();

pub fn deinit(graph: *Graph, alloc: Allocator) void {
    for (graph.nodes.items) |*node| {
        node.deinit(alloc);
    }
    graph.nodes.deinit(alloc);

    for (graph.inputs.items) |*in| {
        if (in.*) |*i| i.deinit(alloc);
    }
    graph.inputs.deinit(alloc);
}

pub fn loadInput(graph: *Graph, idx: usize, val: Tensor) void {
    graph.inputs.items[idx] = val;
}

fn insert(graph: *Graph, alloc: Allocator, node: Node) !NodeId {
    const id = NodeId{ .idx = graph.nodes.items.len };
    try graph.nodes.append(alloc, node);
    return id;
}

pub fn input(graph: *Graph, alloc: Allocator) !NodeId {
    const input_id = graph.inputs.items.len;
    const node = Node{ .ty = .{ .input = input_id } };

    return try graph.nodes.append(alloc, node);
}

test {
    _ = @import("node.zig");
}

test "basic graph" {
    var graph = Graph{};
    defer graph.deinit(std.testing.allocator);
}
