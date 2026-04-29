//! The core computation graph architecture

const std = @import("std");
const Allocator = std.mem.Allocator;
const Tensor = @import("matstack").Tensor;

const Instruction = @import("matstack").Instruction;

const Node = @import("node.zig");
const NodeId = Node.NodeId;
const NodeType = Node.NodeType;

nodes: std.ArrayList(Node) = .empty,
inputs: std.ArrayList(Tensor) = .empty,

const Graph = @This();

pub fn deinit(graph: *Graph, alloc: Allocator) void {
    for (graph.nodes.items) |*node| {
        node.deinit(alloc);
    }
    graph.nodes.deinit(alloc);

    for (graph.inputs.items) |*in| {
        in.deinit(alloc);
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

    try graph.inputs.append(alloc, undefined);

    return try graph.insert(alloc, node);
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

    return try graph.insert(alloc, .{
        .ty = node_type,
    });
}

pub fn relu(graph: *Graph, alloc: Allocator, x: NodeId) !NodeId {
    const node_type: NodeType = .{ .operation = .{
        .relu = .{ .x = x },
    } };

    return try graph.insert(alloc, .{
        .ty = node_type,
    });
}

pub fn sum(graph: *Graph, alloc: Allocator, x: NodeId) !NodeId {
    const node_type: NodeType = .{ .operation = .{
        .sum = .{ .x = x },
    } };

    return try graph.insert(alloc, .{
        .ty = node_type,
    });
}

pub fn add(graph: *Graph, alloc: Allocator, A: NodeId, B: NodeId) !NodeId {
    const node_type: NodeType = .{ .operation = .{
        .add = .{ .A = A, .B = B },
    } };

    return try graph.insert(alloc, .{
        .ty = node_type,
    });
}

pub fn regularization(graph: *Graph, alloc: Allocator, W: NodeId, epsilon: f32) !NodeId {
    const node_type: NodeType = .{ .operation = .{
        .regularization = .{ .W = W, .epsilon = epsilon },
    } };

    return try graph.insert(alloc, .{
        .ty = node_type,
    });
}

pub fn cross_entropy(graph: *Graph, alloc: Allocator, v: NodeId, y: NodeId) !NodeId {
    const node_type: NodeType = .{ .operation = .{
        .cross_entropy = .{ .v = v, .y = y },
    } };

    return try graph.insert(alloc, .{
        .ty = node_type,
    });
}

pub fn mse(graph: *Graph, alloc: Allocator, v: NodeId, y: NodeId) !NodeId {
    const node_type: NodeType = .{ .operation = .{
        .mse = .{ .v = v, .y = y },
    } };

    return try graph.insert(alloc, .{
        .ty = node_type,
    });
}

pub fn transpose(graph: *Graph, alloc: Allocator, X: NodeId) !NodeId {
    const node_type: NodeType = .{ .operation = .{
        .transpose = .{ .X = X },
    } };

    return try graph.insert(alloc, .{
        .ty = node_type,
    });
}

pub fn softmax(graph: *Graph, alloc: Allocator, x: NodeId) !NodeId {
    const node_type: NodeType = .{ .operation = .{
        .softmax = .{ .x = x },
    } };

    return try graph.insert(alloc, .{
        .ty = node_type,
    });
}

pub fn eval(graph: *Graph, alloc: Allocator, node: NodeId) !Tensor {
    switch (graph.nodes.items[node.idx].ty) {
        .constant => |c| return try c.clone(alloc),
        .input => |i| return graph.inputs.items[i].clone(alloc),
        .operation => |op| {
            switch (op) {
                .linear => |l| {
                    var W = try graph.eval(alloc, l.W);
                    defer W.deinit(alloc);

                    var x = try graph.eval(alloc, l.x);
                    defer x.deinit(alloc);

                    var b = try graph.eval(alloc, l.b);
                    defer b.deinit(alloc);

                    var Wx = try W.matmul(x, alloc);
                    defer Wx.deinit(alloc);

                    const y = try Wx.add(b, alloc);
                    return y;
                },
                else => @panic("TODO\n"),
            }
        },
    }
}

pub fn compile(graph: *Graph, alloc: Allocator, instr: *std.ArrayList(Instruction)) !void {
    _ = graph;
    _ = alloc;
    _ = instr;
}

test {
    _ = @import("node.zig");
}

test "basic graph" {
    var graph = Graph{};
    defer graph.deinit(std.testing.allocator);
}

test "Linear forward" {
    const alloc = std.testing.allocator;

    var graph = Graph{};
    defer graph.deinit(alloc);

    const W = try graph.input(alloc);
    const x = try graph.input(alloc);
    const b = try graph.input(alloc);

    const y = try graph.linear(alloc, W, x, b);

    var W_tensor: Tensor = try .makeTensor(alloc, &[2]usize{ 3, 3 });
    var x_tensor: Tensor = try .makeTensor(alloc, &[2]usize{ 3, 1 });
    var b_tensor: Tensor = try .makeTensor(alloc, &[2]usize{ 3, 1 });

    W_tensor.setMany(&[_]f32{ 1, 5, 7, 3, 9, -1, 0, 2, 2 });
    x_tensor.setMany(&[_]f32{ 0, 5, 2 });
    b_tensor.setMany(&[_]f32{ 1, 0, 1 });

    graph.loadInput(0, W_tensor);
    graph.loadInput(1, x_tensor);
    graph.loadInput(2, b_tensor);

    var res = try graph.eval(alloc, y);
    defer res.deinit(alloc);

    try std.testing.expectEqualSlices(usize, &[_]usize{ 3, 1 }, res.shape);
    try std.testing.expectEqualSlices(f32, &[_]f32{ 40, 43, 15 }, res.data);
}
