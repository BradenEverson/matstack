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

grads: std.AutoHashMapUnmanaged(NodeId, Tensor) = .empty,
cache: std.AutoHashMapUnmanaged(NodeId, Tensor) = .empty,

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

    var grads = graph.grads.valueIterator();
    while (grads.next()) |g| g.deinit(alloc);
    graph.grads.deinit(alloc);

    var cache = graph.cache.valueIterator();
    while (cache.next()) |c| c.deinit(alloc);
    graph.cache.deinit(alloc);
}

fn accumulateGrad(graph: *Graph, alloc: Allocator, idx: NodeId, grad: Tensor) !void {
    if (graph.grads.getPtr(idx)) |existing| {
        const summed = try existing.*.add(grad, alloc);

        existing.deinit(alloc);
        existing.* = summed;
    } else {
        try graph.grads.put(alloc, idx, grad);
    }
}

fn zeroGrad(graph: *Graph, idx: NodeId) void {
    graph.grads.remove(idx);
}

pub fn loadInput(graph: *Graph, alloc: Allocator, in: NodeId, val: Tensor) !void {
    const node = graph.nodes.items[in.idx];
    graph.inputs.items[node.ty.input] = val;
    const clone = try val.clone(alloc);
    try graph.cache.put(alloc, in, clone);
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
                    try graph.cache.put(alloc, node, try y.clone(alloc));

                    return y;
                },

                .regularization => |r| {
                    var W = try graph.eval(alloc, r.W);
                    defer W.deinit(alloc);

                    var two: Tensor = try .makeTensor(alloc, &[_]usize{1});
                    two.setMany(&[_]f32{2});
                    defer two.deinit(alloc);

                    var eps: Tensor = try .makeTensor(alloc, &[_]usize{1});
                    eps.setMany(&[_]f32{r.epsilon});
                    defer eps.deinit(alloc);

                    var W_square = try W.pow(two, alloc);
                    defer W_square.deinit(alloc);

                    var norm = try W_square.sumAll(alloc);
                    defer norm.deinit(alloc);

                    const res = try norm.mul(eps, alloc);
                    try graph.cache.put(alloc, node, try res.clone(alloc));
                    return res;
                },

                .add => |a| {
                    var A = try graph.eval(alloc, a.A);
                    defer A.deinit(alloc);

                    var B = try graph.eval(alloc, a.B);
                    defer B.deinit(alloc);

                    const res = try A.add(B, alloc);
                    try graph.cache.put(alloc, node, try res.clone(alloc));
                    return res;
                },

                .relu => |r| {
                    var x = try graph.eval(alloc, r.x);
                    defer x.deinit(alloc);

                    const res = try x.relu(alloc);
                    try graph.cache.put(alloc, node, try res.clone(alloc));
                    return res;
                },

                .mse => |m| {
                    var v = try graph.eval(alloc, m.v);
                    defer v.deinit(alloc);

                    var y = try graph.eval(alloc, m.y);
                    defer y.deinit(alloc);

                    var diff = try y.sub(v, alloc);
                    defer diff.deinit(alloc);

                    var two: Tensor = try .makeTensor(alloc, &[_]usize{1});
                    two.setMany(&[_]f32{2});
                    defer two.deinit(alloc);

                    var square = try diff.pow(two, alloc);
                    defer square.deinit(alloc);

                    var sum = try square.sumReduce(alloc, 0);
                    defer sum.deinit(alloc);

                    const res = try sum.div(two, alloc);
                    try graph.cache.put(alloc, node, try res.clone(alloc));
                    return res;
                },

                .transpose => |t| {
                    var x = try graph.eval(alloc, t.X);
                    try x.transposeMatInPlace();

                    try graph.cache.put(alloc, node, try x.clone(alloc));
                    return x;
                },

                else => @panic("TODO\n"),
            }
        },
    }
}

pub fn backward(graph: *Graph, alloc: Allocator, loss: NodeId) !Tensor {
    var seed = try Tensor.makeTensor(alloc, &[_]usize{1});
    seed.setMany(&[_]f32{1.0});
    try graph.gradients.put(loss, seed);

    var i = graph.nodes.items.len;
    while (i > 0) {
        i -= 1;
        const node = NodeId{ .idx = i };
        const grad_out = graph.gradients.get(node).?;

        try graph.backwardOn(alloc, node, grad_out);
    }
}

pub fn backwardOn(graph: *Graph, alloc: Allocator, node_id: NodeId, grad: Tensor) !void {
    const node = graph.nodes.items[node_id.idx];
    switch (node.ty) {
        .operation => |o| switch (o) {
            .linear => |l| {
                const W = graph.cache.get(l.W).?;
                const x = graph.cache.get(l.x).?;

                var x_t = try x.transposeMat(alloc);
                defer x_t.deinit(alloc);

                var W_t = try W.transposeMat(alloc);
                defer W_t.deinit(alloc);

                const dW = try grad.matmul(x_t, alloc);
                const dx = try W_t.matmul(grad, alloc);
                const db = try grad.clone(alloc);

                try graph.accumulateGrad(alloc, l.W, dW);
                try graph.accumulateGrad(alloc, l.x, dx);
                try graph.accumulateGrad(alloc, l.b, db);
            },

            .relu => |r| {
                const x = graph.cache.get(r.x).?;

                var zero: Tensor = try .makeTensor(alloc, &[_]usize{1});
                zero.setMany(&[_]f32{0});
                defer zero.deinit(alloc);

                var x_mask = try x.gt(zero, alloc);
                defer x_mask.deinit(alloc);

                const dx = try grad.mul(x_mask, alloc);
                try graph.accumulateGrad(alloc, r.x, dx);
            },

            else => @panic("TODO\n"),
        },
        else => {},
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

    try graph.loadInput(alloc, W, W_tensor);
    try graph.loadInput(alloc, x, x_tensor);
    try graph.loadInput(alloc, b, b_tensor);

    var res = try graph.eval(alloc, y);
    defer res.deinit(alloc);

    try std.testing.expectEqualSlices(usize, &[_]usize{ 3, 1 }, res.shape);
    try std.testing.expectEqualSlices(f32, &[_]f32{ 40, 43, 15 }, res.data);
}

test "Regularization" {
    const alloc = std.testing.allocator;

    var graph = Graph{};
    defer graph.deinit(alloc);

    const W = try graph.input(alloc);

    const y = try graph.regularization(alloc, W, 0.1);

    var W_tensor: Tensor = try .makeTensor(alloc, &[2]usize{ 2, 3 });

    W_tensor.setMany(&[_]f32{ 2, 4, 5, 10, 0, -2 });

    try graph.loadInput(alloc, W, W_tensor);

    var res = try graph.eval(alloc, y);
    defer res.deinit(alloc);

    try std.testing.expectApproxEqAbs(14.9, res.data[0], 1e-4);
}

test "Add" {
    const alloc = std.testing.allocator;

    var graph = Graph{};
    defer graph.deinit(alloc);

    const a = try graph.input(alloc);
    const b = try graph.input(alloc);

    const y = try graph.add(alloc, a, b);

    var a_tensor: Tensor = try .makeTensor(alloc, &[2]usize{ 2, 1 });
    var b_tensor: Tensor = try .makeTensor(alloc, &[2]usize{ 2, 1 });

    a_tensor.setMany(&[_]f32{ 3, 5 });
    b_tensor.setMany(&[_]f32{ 1, 2 });

    try graph.loadInput(alloc, a, a_tensor);
    try graph.loadInput(alloc, b, b_tensor);

    var res = try graph.eval(alloc, y);
    defer res.deinit(alloc);

    try std.testing.expectEqualSlices(f32, &[_]f32{ 4, 7 }, res.data);
}

test "ReLU" {
    const alloc = std.testing.allocator;

    var graph = Graph{};
    defer graph.deinit(alloc);

    const x = try graph.input(alloc);

    const y = try graph.relu(alloc, x);

    var x_tensor: Tensor = try .makeTensor(alloc, &[2]usize{ 2, 3 });
    x_tensor.setMany(&[_]f32{ -1, 5, 9, 0, -20, 3 });

    try graph.loadInput(alloc, x, x_tensor);

    var res = try graph.eval(alloc, y);
    defer res.deinit(alloc);

    try std.testing.expectEqualSlices(f32, &[_]f32{ 0, 5, 9, 0, 0, 3 }, res.data);
}

test "mse" {
    const alloc = std.testing.allocator;

    var graph = Graph{};
    defer graph.deinit(alloc);

    const y = try graph.input(alloc);
    const v = try graph.input(alloc);

    const L = try graph.mse(alloc, v, y);

    var y_tensor: Tensor = try .makeTensor(alloc, &[2]usize{ 2, 1 });
    y_tensor.setMany(&[_]f32{ 10, 5 });

    var v_tensor: Tensor = try .makeTensor(alloc, &[2]usize{ 2, 1 });
    v_tensor.setMany(&[_]f32{ -7, 4 });

    try graph.loadInput(alloc, y, y_tensor);
    try graph.loadInput(alloc, v, v_tensor);

    var res = try graph.eval(alloc, L);
    defer res.deinit(alloc);

    try std.testing.expectApproxEqAbs(res.data[0], 145, 1e-4);
}

test "forward pass" {
    const alloc = std.testing.allocator;

    var graph = Graph{};
    defer graph.deinit(alloc);

    const x = try graph.input(alloc);
    const y = try graph.input(alloc);

    const W = try graph.input(alloc);
    const M = try graph.input(alloc);
    const b = try graph.input(alloc);
    const c = try graph.input(alloc);

    const u = try graph.linear(alloc, W, x, b);
    const h = try graph.relu(alloc, u);

    const v = try graph.linear(alloc, M, h, c);
    const L = try graph.mse(alloc, v, y);

    const S1 = try graph.regularization(alloc, W, 0.01);
    const S2 = try graph.regularization(alloc, M, 0.01);

    const S = try graph.add(alloc, S1, S2);
    const J = try graph.add(alloc, L, S);

    var x_tensor: Tensor = try .makeTensor(alloc, &[2]usize{ 2, 1 });
    x_tensor.setMany(&[_]f32{ -10, 1 });
    try graph.loadInput(alloc, x, x_tensor);

    var y_tensor: Tensor = try .makeTensor(alloc, &[2]usize{ 2, 1 });
    y_tensor.setMany(&[_]f32{ 10, 5 });
    try graph.loadInput(alloc, y, y_tensor);

    var W_tensor: Tensor = try .makeTensor(alloc, &[2]usize{ 3, 2 });
    W_tensor.setMany(&[_]f32{ 1, 0, 0, 1, 0, 0 });
    try graph.loadInput(alloc, W, W_tensor);

    var M_tensor: Tensor = try .makeTensor(alloc, &[2]usize{ 2, 3 });
    M_tensor.setMany(&[_]f32{ 0, -1, 2, 1, 3, -5 });
    try graph.loadInput(alloc, M, M_tensor);

    var b_tensor: Tensor = try .makeTensor(alloc, &[2]usize{ 3, 1 });
    b_tensor.setMany(&[_]f32{ 1, 2, 3 });
    try graph.loadInput(alloc, b, b_tensor);

    var c_tensor: Tensor = try .makeTensor(alloc, &[2]usize{ 2, 1 });
    c_tensor.setMany(&[_]f32{ -10, 10 });
    try graph.loadInput(alloc, c, c_tensor);

    var res = try graph.eval(alloc, J);
    defer res.deinit(alloc);

    try std.testing.expectApproxEqAbs(res.data[0], 145.42, 1e-4);
}

test "Linear layer dW" {
    const alloc = std.testing.allocator;

    var graph = Graph{};
    defer graph.deinit(alloc);

    const W = try graph.input(alloc);
    const x = try graph.input(alloc);
    const b = try graph.input(alloc);

    const y = try graph.linear(alloc, W, x, b);

    var W_tensor: Tensor = try .makeTensor(alloc, &[2]usize{ 2, 3 });
    var x_tensor: Tensor = try .makeTensor(alloc, &[2]usize{ 3, 1 });
    var b_tensor: Tensor = try .makeTensor(alloc, &[2]usize{ 2, 1 });

    W_tensor.setMany(&[_]f32{ 0, 0, 0, 0, 0, 0 });
    x_tensor.setMany(&[_]f32{ 5, 0, 7 });
    b_tensor.setMany(&[_]f32{ 1, 0 });

    try graph.loadInput(alloc, W, W_tensor);
    try graph.loadInput(alloc, x, x_tensor);
    try graph.loadInput(alloc, b, b_tensor);

    var res = try graph.eval(alloc, y);
    defer res.deinit(alloc);

    var grad_tensor: Tensor = try .makeTensor(alloc, &[2]usize{ 2, 1 });
    grad_tensor.setMany(&[_]f32{ 0, 1.5 });
    defer grad_tensor.deinit(alloc);

    try graph.backwardOn(alloc, y, grad_tensor);

    const dW = graph.grads.get(W).?;
    try std.testing.expectEqualSlices(f32, &[_]f32{ 0, 0, 0, 7.5, 0, 10.5 }, dW.data);
}

test "Linear layer dx" {
    const alloc = std.testing.allocator;

    var graph = Graph{};
    defer graph.deinit(alloc);

    const W = try graph.input(alloc);
    const x = try graph.input(alloc);
    const b = try graph.input(alloc);

    const y = try graph.linear(alloc, W, x, b);

    var W_tensor: Tensor = try .makeTensor(alloc, &[2]usize{ 2, 3 });
    var x_tensor: Tensor = try .makeTensor(alloc, &[2]usize{ 3, 1 });
    var b_tensor: Tensor = try .makeTensor(alloc, &[2]usize{ 2, 1 });

    W_tensor.setMany(&[_]f32{ -1, 3, 2, 5, 0, 0.1 });
    x_tensor.setMany(&[_]f32{ 0, 0, 0 });
    b_tensor.setMany(&[_]f32{ 0, 0 });

    try graph.loadInput(alloc, W, W_tensor);
    try graph.loadInput(alloc, x, x_tensor);
    try graph.loadInput(alloc, b, b_tensor);

    var res = try graph.eval(alloc, y);
    defer res.deinit(alloc);

    var grad_tensor: Tensor = try .makeTensor(alloc, &[2]usize{ 2, 1 });
    grad_tensor.setMany(&[_]f32{ 0.5, -1 });
    defer grad_tensor.deinit(alloc);

    try graph.backwardOn(alloc, y, grad_tensor);

    const dx = graph.grads.get(x).?;
    try std.testing.expectEqualSlices(f32, &[_]f32{ -5.5, 1.5, 0.9 }, dx.data);
}

test "Linear layer db" {
    const alloc = std.testing.allocator;

    var graph = Graph{};
    defer graph.deinit(alloc);

    const W = try graph.input(alloc);
    const x = try graph.input(alloc);
    const b = try graph.input(alloc);

    const y = try graph.linear(alloc, W, x, b);

    var W_tensor: Tensor = try .makeTensor(alloc, &[2]usize{ 2, 3 });
    var x_tensor: Tensor = try .makeTensor(alloc, &[2]usize{ 3, 1 });
    var b_tensor: Tensor = try .makeTensor(alloc, &[2]usize{ 2, 1 });

    W_tensor.setMany(&[_]f32{ -1, 3, 2, 5, 0, 0.1 });
    x_tensor.setMany(&[_]f32{ 0, 0, 0 });
    b_tensor.setMany(&[_]f32{ 0, 0 });

    try graph.loadInput(alloc, W, W_tensor);
    try graph.loadInput(alloc, x, x_tensor);
    try graph.loadInput(alloc, b, b_tensor);

    var res = try graph.eval(alloc, y);
    defer res.deinit(alloc);

    var grad_tensor: Tensor = try .makeTensor(alloc, &[2]usize{ 2, 1 });
    grad_tensor.setMany(&[_]f32{ 1, 2 });
    defer grad_tensor.deinit(alloc);

    try graph.backwardOn(alloc, y, grad_tensor);

    const db = graph.grads.get(b).?;
    try std.testing.expectEqualSlices(f32, &[_]f32{ 1, 2 }, db.data);
}

test "Linear relu dx" {
    const alloc = std.testing.allocator;

    var graph = Graph{};
    defer graph.deinit(alloc);

    const x = try graph.input(alloc);

    const y = try graph.relu(alloc, x);

    var x_tensor: Tensor = try .makeTensor(alloc, &[2]usize{ 2, 1 });
    x_tensor.setMany(&[_]f32{ -10, 7 });
    try graph.loadInput(alloc, x, x_tensor);

    var res = try graph.eval(alloc, y);
    defer res.deinit(alloc);

    var grad_tensor: Tensor = try .makeTensor(alloc, &[2]usize{ 2, 1 });
    grad_tensor.setMany(&[_]f32{ 5, -2 });
    defer grad_tensor.deinit(alloc);

    try graph.backwardOn(alloc, y, grad_tensor);

    const dx = graph.grads.get(x).?;
    try std.testing.expectEqualSlices(f32, &[_]f32{ 0, -2 }, dx.data);
}
