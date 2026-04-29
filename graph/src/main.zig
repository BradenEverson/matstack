const std = @import("std");
const Graph = @import("graph.zig");
const Tensor = @import("matstack").Tensor;

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;

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

    try graph.backward(alloc, J);
}

test {
    _ = @import("graph.zig");
}
