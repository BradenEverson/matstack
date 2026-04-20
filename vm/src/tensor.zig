//! Tensors are the core value of matstack, so we should probably design 'em pretty well

const std = @import("std");
const Allocator = std.mem.Allocator;

const Tensor = @This();

pub const TensorError = error{
    InvalidShapeForOp,
    OperandSizesDoNotAgree,
};

data: []f32,

/// The shape in row-first order
shape: []usize,

/// Offset for slices into existing tensors
offset: usize = 0,

/// for each dimension along the shape,
/// how many elements we move forward
/// flatly to get to the next index.
/// ex: in a 2x3 matrix, strides would
/// be [3, 1] to move down a row or col
strides: []usize,

pub fn deinit(self: *Tensor, alloc: Allocator) void {
    alloc.free(self.data);
    alloc.free(self.shape);
    alloc.free(self.strides);
}

pub fn fromBytes(alloc: Allocator, buf: []const u8) !struct { Tensor, []const u8 } {
    var rest = buf;

    const n_dims = rest[0];
    rest = rest[1..];

    const shape = try alloc.alloc(usize, n_dims);

    for (shape) |*dim| {
        dim.* = std.mem.readInt(u32, &[4]u8{
            rest[0],
            rest[1],
            rest[2],
            rest[3],
        }, .little);
        rest = rest[4..];
    }
    defer alloc.free(shape); // will get realloced from makeTensor

    const tensor: Tensor = try .makeTensor(alloc, shape);

    for (tensor.data) |*val| {
        const bits = std.mem.readInt(u32, &[4]u8{
            rest[0],
            rest[1],
            rest[2],
            rest[3],
        }, .little);
        rest = rest[4..];

        val.* = @bitCast(bits);
    }

    return .{
        tensor,
        rest,
    };
}

pub fn toBytes(self: *const Tensor, alloc: Allocator, out: *std.ArrayList(u8)) !void {
    if (self.shape.len == 0) {
        // 1D
        try out.append(alloc, 1);
        // Single dimension, 1 as a u32
        try out.append(alloc, 0x01);
        try out.append(alloc, 0x00);
        try out.append(alloc, 0x00);
        try out.append(alloc, 0x00);
    } else {
        const dims: u8 = @truncate(self.shape.len);
        try out.append(alloc, dims);

        for (self.shape) |dim| {
            const d: u32 = @truncate(dim);
            var bytes: [4]u8 = undefined;
            std.mem.writeInt(u32, &bytes, d, .little);

            try out.append(alloc, bytes[0]);
            try out.append(alloc, bytes[1]);
            try out.append(alloc, bytes[2]);
            try out.append(alloc, bytes[3]);
        }
    }

    var bytes: [4]u8 = undefined;

    for (self.data) |val| {
        const bits: u32 = @bitCast(val);

        std.mem.writeInt(u32, &bytes, bits, .little);

        try out.append(alloc, bytes[0]);
        try out.append(alloc, bytes[1]);
        try out.append(alloc, bytes[2]);
        try out.append(alloc, bytes[3]);
    }
}

pub fn makeTensor(alloc: Allocator, shape: []const usize) !Tensor {
    const shapeOwned = try alloc.dupe(usize, shape);
    errdefer alloc.free(shapeOwned);

    const strides = try alloc.alloc(usize, shape.len);
    errdefer alloc.free(strides);

    if (shape.len > 0) {
        strides[shape.len - 1] = 1;
        var i = shape.len - 1;
        while (i > 0) {
            i -= 1;
            strides[i] = strides[i + 1] * shape[i + 1];
        }
    }

    var n: usize = 1;
    for (shape) |s| n *= s;

    const data = try alloc.alloc(f32, n);

    return .{
        .data = data,
        .shape = shapeOwned,
        .strides = strides,
    };
}

pub fn clone(from: *const Tensor, alloc: Allocator) !Tensor {
    const shape = try alloc.dupe(usize, from.shape);
    errdefer alloc.free(shape);

    const strides = try alloc.dupe(usize, from.strides);
    errdefer alloc.free(strides);

    const data = try alloc.dupe(f32, from.data);
    errdefer alloc.free(data);

    return .{
        .shape = shape,
        .data = data,
        .strides = strides,
        .offset = from.offset,
    };
}

pub fn flattenIdx(self: *const Tensor, idx: []const usize) usize {
    var res = self.offset;

    for (idx, 0..) |id, i| {
        res += self.strides[i] * id;
    }

    return res;
}

pub fn at(self: *const Tensor, idx: []const usize) f32 {
    const flat = self.flattenIdx(idx);
    return self.data[flat];
}

pub fn atMut(self: *Tensor, idx: []const usize) *f32 {
    const flat = self.flattenIdx(idx);
    return &self.data[flat];
}

pub fn set(self: *Tensor, idx: []const usize, val: f32) void {
    self.atMut(idx).* = val;
}

pub fn setMany(self: *Tensor, vals: []const f32) void {
    for (vals, 0..) |val, i|
        self.data[i] = val;
}

pub fn isZero(a: Tensor) bool {
    var allZeros = true;

    for (a.data) |val| {
        if (!std.math.approxEqAbs(f32, val, 0, 1e-10)) {
            allZeros = false;
            break;
        }
    }

    return allZeros;
}

pub fn sumReduceRows(self: *const Tensor, alloc: Allocator) !Tensor {
    if (self.shape.len != 2)
        return error.InvalidShapeForOp;

    const M = self.shape[0];
    const N = self.shape[1];
    var result = try makeTensor(alloc, &[2]usize{ M, 1 });

    for (0..M) |i| {
        var sum: f32 = 0.0;
        for (0..N) |k| {
            sum += self.at(&.{ i, k });
        }
        result.set(&.{ i, 0 }, sum);
    }

    return result;
}

pub fn transposeMatInPlace(self: *Tensor) !void {
    if (self.shape.len != 2)
        return error.InvalidShapeForOp;

    const tmp = self.strides[0];
    self.strides[0] = self.strides[1];
    self.strides[1] = tmp;

    const tmp_shape = self.shape[0];
    self.shape[0] = self.shape[1];
    self.shape[1] = tmp_shape;
}

pub fn transposeMat(self: *const Tensor, alloc: Allocator) !Tensor {
    if (self.shape.len != 2)
        return error.InvalidShapeForOp;

    var copy = try self.clone(alloc);
    try copy.transposeMatInPlace();

    return copy;
}

pub fn matmul(a: Tensor, b: Tensor, alloc: Allocator) !Tensor {
    if (a.shape.len != 2 or b.shape.len != 2)
        return error.InvalidShapeForOp;

    const M = a.shape[0];
    const K = a.shape[1];

    if (K != b.shape[0])
        return error.OperandSizesDoNotAgree;

    const N = b.shape[1];

    var res: Tensor = try .makeTensor(alloc, &[2]usize{ M, N });

    for (0..M) |i| {
        for (0..N) |j| {
            var sum: f32 = 0.0;
            for (0..K) |k| {
                sum += a.at(&.{ i, k }) * b.at(&.{ k, j });
            }
            atMut(&res, &.{ i, j }).* = sum;
        }
    }

    return res;
}

pub fn inPlaceRelu(self: *Tensor) void {
    for (self.data) |*val| {
        if (val.* < 0) val.* = 0;
    }
}

pub fn relu(self: *const Tensor, alloc: Allocator) !Tensor {
    var copy = try self.clone(alloc);
    copy.inPlaceRelu();

    return copy;
}

pub fn subInPlace(self: *Tensor, b: Tensor) !void {
    if (!std.mem.eql(usize, self.shape, b.shape))
        return error.OperandSizesDoNotAgree;

    for (self.data, 0..) |*a_val, i|
        a_val.* -= b.data[i];
}

pub fn sub(a: Tensor, b: Tensor, alloc: Allocator) !Tensor {
    var copy = try a.clone(alloc);
    try copy.subInPlace(b);

    return copy;
}

pub fn addInPlace(self: *Tensor, b: Tensor) !void {
    if (!std.mem.eql(usize, self.shape, b.shape))
        return error.OperandSizesDoNotAgree;

    for (self.data, 0..) |*a_val, i|
        a_val.* += b.data[i];
}

pub fn add(a: Tensor, b: Tensor, alloc: Allocator) !Tensor {
    var copy = try a.clone(alloc);
    try copy.addInPlace(b);

    return copy;
}

pub fn softmax(self: *const Tensor, alloc: Allocator) !Tensor {
    if (self.shape.len != 2)
        return error.InvalidShapeForOp;

    const M = self.shape[0];
    const N = self.shape[1];
    var result = try makeTensor(alloc, self.shape);

    for (0..M) |i| {
        var max: f32 = -std.math.inf(f32);
        for (0..N) |k| {
            const v = self.at(&.{ i, k });
            if (v > max) max = v;
        }

        var sum: f32 = 0.0;
        for (0..N) |k| {
            const v = std.math.exp(self.at(&.{ i, k }) - max);
            result.set(&.{ i, k }, v);
            sum += v;
        }

        for (0..N) |k| {
            result.atMut(&.{ i, k }).* /= sum;
        }
    }

    return result;
}

pub fn crossEntropyLoss(
    predictions: *const Tensor,
    labels: *const Tensor,
    alloc: Allocator,
) !Tensor {
    if (predictions.shape.len != 2 or labels.shape.len != 2)
        return error.InvalidShapeForOp;
    if (!std.mem.eql(usize, predictions.shape, labels.shape))
        return error.OperandSizesDoNotAgree;

    const M = predictions.shape[0];
    const N = predictions.shape[1];
    var total_loss: f32 = 0.0;

    for (0..M) |i| {
        for (0..N) |k| {
            const p = predictions.at(&.{ i, k });
            const y = labels.at(&.{ i, k });
            if (y > 0.0) {
                const p_clamped = @max(p, 1e-7);
                total_loss -= y * std.math.log(f32, std.math.e, p_clamped);
            }
        }
    }

    var result = try makeTensor(alloc, &[1]usize{1});
    result.data[0] = total_loss / @as(f32, @floatFromInt(M));
    return result;
}

test "make a scalar" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();

    const tensor: Tensor = try .makeTensor(arena.allocator(), &[1]usize{1});

    try std.testing.expectApproxEqAbs(0.0, tensor.at(&[1]usize{0}), 1e-5);
}

test "make a matrix" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();

    const tensor: Tensor = try .makeTensor(arena.allocator(), &[2]usize{ 2, 3 });

    try std.testing.expectApproxEqAbs(0.0, tensor.at(&[1]usize{0}), 1e-5);
}

test "matmul" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();

    var A: Tensor = try .makeTensor(arena.allocator(), &[2]usize{ 2, 3 });
    var B: Tensor = try .makeTensor(arena.allocator(), &[2]usize{ 3, 2 });

    A.setMany(&[_]f32{ 1, 2, 1, 0, 1, 0 });
    B.setMany(&[_]f32{ 2, 5, 6, 7, 1, 8 });

    const C = try A.matmul(B, arena.allocator());

    try std.testing.expectEqualSlices(usize, &[_]usize{ 2, 2 }, C.shape);
    try std.testing.expectEqualSlices(f32, &[_]f32{ 15, 27, 6, 7 }, C.data);
}

test "transpose" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();

    var A: Tensor = try .makeTensor(arena.allocator(), &[2]usize{ 2, 3 });
    try A.transposeMatInPlace();
    A.setMany(&[_]f32{ 1, 2, 1, 0, 1, 0 });

    try std.testing.expectEqualSlices(usize, &[_]usize{ 3, 2 }, A.shape);
    try std.testing.expectEqualSlices(usize, &[_]usize{ 1, 3 }, A.strides);
}

test "add" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();

    var A: Tensor = try .makeTensor(arena.allocator(), &[2]usize{ 2, 3 });
    var B: Tensor = try .makeTensor(arena.allocator(), &[2]usize{ 2, 3 });

    A.setMany(&[_]f32{ 1, 2, 1, 0, 1, 0 });
    B.setMany(&[_]f32{ 2, 5, 6, 7, 1, 8 });

    const C = try A.add(B, arena.allocator());

    try std.testing.expectEqualSlices(usize, &[_]usize{ 2, 3 }, C.shape);
    try std.testing.expectEqualSlices(f32, &[_]f32{ 3, 7, 7, 7, 2, 8 }, C.data);
}

test "W @ X^T" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();

    var A: Tensor = try .makeTensor(arena.allocator(), &[2]usize{ 2, 3 });
    var B: Tensor = try .makeTensor(arena.allocator(), &[2]usize{ 2, 3 });

    A.setMany(&[_]f32{ 1, 2, 1, 0, 1, 0 });
    B.setMany(&[_]f32{ 2, 5, 6, 7, 1, 8 });
    try B.transposeMatInPlace();

    const C = try A.matmul(B, arena.allocator());

    try std.testing.expectEqualSlices(usize, &[_]usize{ 2, 2 }, C.shape);
    try std.testing.expectEqualSlices(f32, &[_]f32{ 18, 17, 5, 1 }, C.data);
}

test "ReLu" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();

    var A: Tensor = try .makeTensor(arena.allocator(), &[2]usize{ 2, 3 });
    A.setMany(&[_]f32{ -1, 2, 1, -80, 1, 0.1 });
    A.inPlaceRelu();

    try std.testing.expectEqualSlices(f32, &[_]f32{ 0, 2, 1, 0, 1, 0.1 }, A.data);
}

test "softmax" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();

    var A: Tensor = try .makeTensor(arena.allocator(), &[2]usize{ 2, 3 });
    A.setMany(&[_]f32{ 1, 2, 3, 1, 1, 1 });

    const S = try A.softmax(arena.allocator());

    try std.testing.expectEqualSlices(usize, &[_]usize{ 2, 3 }, S.shape);

    const row0_sum = S.data[0] + S.data[1] + S.data[2];
    const row1_sum = S.data[3] + S.data[4] + S.data[5];
    try std.testing.expectApproxEqAbs(1.0, row0_sum, 1e-5);
    try std.testing.expectApproxEqAbs(1.0, row1_sum, 1e-5);

    try std.testing.expectApproxEqAbs(S.data[3], S.data[4], 1e-5);
    try std.testing.expectApproxEqAbs(S.data[4], S.data[5], 1e-5);

    try std.testing.expectApproxEqAbs(0.09003, S.data[0], 1e-4);
    try std.testing.expectApproxEqAbs(0.24473, S.data[1], 1e-4);
    try std.testing.expectApproxEqAbs(0.66524, S.data[2], 1e-4);
}

test "cross entropy loss" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();

    var predictions: Tensor = try .makeTensor(arena.allocator(), &[2]usize{ 2, 3 });
    var labels: Tensor = try .makeTensor(arena.allocator(), &[2]usize{ 2, 3 });

    predictions.setMany(&[_]f32{
        0.01, 0.01, 0.98,
        0.98, 0.01, 0.01,
    });
    labels.setMany(&[_]f32{
        0, 0, 1,
        0, 0, 1,
    });

    const loss = try Tensor.crossEntropyLoss(&predictions, &labels, arena.allocator());

    try std.testing.expectEqualSlices(usize, &[_]usize{1}, loss.shape);

    try std.testing.expectApproxEqAbs(2.31269, loss.data[0], 1e-4);
}

test "cmp" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();

    var A: Tensor = try .makeTensor(arena.allocator(), &[2]usize{ 2, 3 });
    var B: Tensor = try .makeTensor(arena.allocator(), &[2]usize{ 2, 3 });

    A.setMany(&[_]f32{ 1, 2, 1, 0, 1, 0 });
    B.setMany(&[_]f32{ 1, 2, 1, 0, 1, 0 });

    const C = try A.sub(B, arena.allocator());

    try std.testing.expect(C.isZero());
}

test "read a tensor" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();

    const bytes = &[_]u8{
        2, // n_dims
        0x02, 0x00, 0x00, 0x00, // 2 rows
        0x03, 0x00, 0x00, 0x00, // 3 cols
        0x00, 0x00, 0x80, 0x3f, // 1
        0x00, 0x00, 0x00, 0x40, // 2
        0x00, 0x00, 0x80, 0x3f, // 1
        0x00, 0x00, 0x00, 0x00, // 0
        0x00, 0x00, 0x80, 0x3f, // 1
        0x00, 0x00, 0x00, 0x00, // 0
    };

    const A, const rest = try Tensor.fromBytes(arena.allocator(), bytes);

    try std.testing.expectEqual(0, rest.len);

    try std.testing.expectEqualSlices(usize, &[_]usize{ 2, 3 }, A.shape);
    try std.testing.expectEqualSlices(f32, &[_]f32{ 1, 2, 1, 0, 1, 0 }, A.data);
}
