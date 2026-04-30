const std = @import("std");
const Graph = @import("graph.zig");
const Tensor = @import("matstack").Tensor;

var prng: ?std.Random.DefaultPrng = null;

fn getRand(io: std.Io) std.Random {
    if (prng) |*r| {
        return r.random();
    } else {
        prng = .init(blk: {
            var seed: u64 = undefined;
            io.random(std.mem.asBytes(&seed));
            break :blk seed;
        });
        return prng.?.random();
    }
}

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

    var x_tensor: Tensor = try .makeTensor(alloc, &[2]usize{ 1, 10 });
    x_tensor.setMany(&[_]f32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 });
    try graph.loadInput(alloc, x, x_tensor);

    var y_tensor: Tensor = try .makeTensor(alloc, &[2]usize{ 1, 10 });
    y_tensor.setMany(&[_]f32{ 1, 4, 9, 16, 25, 36, 49, 64, 81, 100 });
    try graph.loadInput(alloc, y, y_tensor);

    var W_tensor: Tensor = try .makeTensor(alloc, &[2]usize{ 3, 1 });
    W_tensor.randomize(getRand(init.io));
    try graph.loadInput(alloc, W, W_tensor);

    var M_tensor: Tensor = try .makeTensor(alloc, &[2]usize{ 1, 3 });
    M_tensor.randomize(getRand(init.io));
    try graph.loadInput(alloc, M, M_tensor);

    var b_tensor: Tensor = try .makeTensor(alloc, &[2]usize{ 3, 1 });
    b_tensor.randomize(getRand(init.io));
    try graph.loadInput(alloc, b, b_tensor);

    var c_tensor: Tensor = try .makeTensor(alloc, &[2]usize{ 1, 1 });
    c_tensor.randomize(getRand(init.io));
    try graph.loadInput(alloc, c, c_tensor);

    var res = try graph.eval(alloc, J);
    defer res.deinit(alloc);

    std.debug.print("{}\n", .{res});

    try graph.backward(alloc, J);
}

test {
    _ = @import("graph.zig");
}
