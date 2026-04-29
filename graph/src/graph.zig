//! The core computation graph architecture
//!
//! pub fn output()

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

pub fn output(graph: *Graph, alloc: Allocator, n: NodeId) !void {
    try graph.outputs.append(alloc, n);
}

pub fn linear(graph: *Graph, alloc: Allocator, W: NodeId, x: NodeId, b: NodeId) !NodeId {
    _ = graph;
    _ = alloc;
    _ = W;
    _ = x;
    _ = b;
}

test {
    _ = @import("node.zig");
}

test "basic graph" {
    var graph = Graph{};
    defer graph.deinit(std.testing.allocator);
}
