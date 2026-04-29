//! The core computation graph architecture

const std = @import("std");
const Allocator = std.mem.Allocator;
const Tensor = @import("matstack").Tensor;

const Node = @import("node.zig");
const NodeId = Node.NodeId;
const NodeType = Node.NodeType;

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

pub fn linear(
    graph: *Graph,
    alloc: Allocator,
    W: NodeId,
    x: NodeId,
    b: NodeId,
) !NodeId {
    const node_type: NodeType = .{ .operation = .{
        .linear = .{ .W = W, .x = x, .b = b },
    } };

    return try graph.nodes.append(alloc, .{
        .ty = .{ .operation = node_type },
    });
}

pub fn relu(graph: *Graph, alloc: Allocator, x: NodeId) !NodeId {
    const node_type: NodeType = .{ .operation = .{
        .relu = .{ .x = x },
    } };

    return try graph.nodes.append(alloc, .{
        .ty = .{ .operation = node_type },
    });
}

pub fn sum(graph: *Graph, alloc: Allocator, x: NodeId) !NodeId {
    const node_type: NodeType = .{ .operation = .{
        .sum = .{ .x = x },
    } };

    return try graph.nodes.append(alloc, .{
        .ty = .{ .operation = node_type },
    });
}

pub fn add(graph: *Graph, alloc: Allocator, A: NodeId, B: NodeId) !NodeId {
    const node_type: NodeType = .{ .operation = .{
        .add = .{ .A = A, .B = B },
    } };

    return try graph.nodes.append(alloc, .{
        .ty = .{ .operation = node_type },
    });
}

pub fn regularization(graph: *Graph, alloc: Allocator, W: NodeId, epsilon: f32) !NodeId {
    const node_type: NodeType = .{ .operation = .{
        .regularization = .{ .W = W, .epsilon = epsilon },
    } };

    return try graph.nodes.append(alloc, .{
        .ty = .{ .operation = node_type },
    });
}

pub fn cross_entropy(graph: *Graph, alloc: Allocator, v: NodeId, y: NodeId) !NodeId {
    const node_type: NodeType = .{ .operation = .{
        .cross_entropy = .{ .v = v, .y = y },
    } };

    return try graph.nodes.append(alloc, .{
        .ty = .{ .operation = node_type },
    });
}

pub fn mse(graph: *Graph, alloc: Allocator, v: NodeId, y: NodeId) !NodeId {
    const node_type: NodeType = .{ .operation = .{
        .mse = .{ .v = v, .y = y },
    } };

    return try graph.nodes.append(alloc, .{
        .ty = .{ .operation = node_type },
    });
}

pub fn transpose(graph: *Graph, alloc: Allocator, X: NodeId) !NodeId {
    const node_type: NodeType = .{ .operation = .{
        .transpose = .{ .X = X },
    } };

    return try graph.nodes.append(alloc, .{
        .ty = .{ .operation = node_type },
    });
}

pub fn softmax(graph: *Graph, alloc: Allocator, x: NodeId) !NodeId {
    const node_type: NodeType = .{ .operation = .{
        .softmax = .{ .x = x },
    } };

    return try graph.nodes.append(alloc, .{
        .ty = .{ .operation = node_type },
    });
}

test {
    _ = @import("node.zig");
}

test "basic graph" {
    var graph = Graph{};
    defer graph.deinit(std.testing.allocator);
}
