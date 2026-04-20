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

/// Equality checks used specifically by the compiler for
/// reducing the size of the constant pool when  redundant tensors
/// are used.
///
/// Because this is coming from constant compiler-generated
/// tensors, we can make a few assumptions. For one, the stride
/// will be unmutated as well as the offset. This means
/// all we need to compare is the shape and data
pub fn equal(A: Tensor, B: Tensor) bool {
    return std.mem.eql(usize, A.shape, B.shape) and std.mem.eql(f32, A.data, B.data);
}

/// Returns the broadcast output shape, or error if shapes are incompatible.
/// Caller owns the returned slice.
pub fn broadcastShape(
    alloc: Allocator,
    a_shape: []const usize,
    b_shape: []const usize,
) ![]usize {
    const out_len = @max(a_shape.len, b_shape.len);
    const out = try alloc.alloc(usize, out_len);
    errdefer alloc.free(out);

    for (0..out_len) |i| {
        // Walk from the right
        const a_dim = if (i < a_shape.len) a_shape[a_shape.len - 1 - i] else 1;
        const b_dim = if (i < b_shape.len) b_shape[b_shape.len - 1 - i] else 1;

        if (a_dim == b_dim) {
            out[out_len - 1 - i] = a_dim;
        } else if (a_dim == 1) {
            out[out_len - 1 - i] = b_dim;
        } else if (b_dim == 1) {
            out[out_len - 1 - i] = a_dim;
        } else {
            return error.IncompatibleBroadcastShapes;
        }
    }

    return out;
}

fn broadcastedFlatIdx(t: *const Tensor, out_idx: []const usize, out_len: usize) usize {
    var flat: usize = t.offset;
    const offset = out_len - t.shape.len;

    for (0..t.shape.len) |i| {
        const out_i = i + offset;
        const idx = if (t.shape[i] == 1) 0 else out_idx[out_i];
        flat += t.strides[i] * idx;
    }

    return flat;
}

pub fn broadcastApply(
    a: *const Tensor,
    b: *const Tensor,
    alloc: Allocator,
    comptime op: fn (f32, f32) f32,
) !Tensor {
    const out_shape = try broadcastShape(alloc, a.shape, b.shape);
    defer alloc.free(out_shape);

    var result = try makeTensor(alloc, out_shape);

    var idx = try alloc.alloc(usize, out_shape.len);
    defer alloc.free(idx);
    @memset(idx, 0);

    const total = result.data.len;
    for (0..total) |flat_out| {
        var rem = flat_out;
        for (0..out_shape.len) |i| {
            idx[i] = rem / result.strides[i];
            rem %= result.strides[i];
        }

        const a_val = a.data[broadcastedFlatIdx(a, idx, out_shape.len)];
        const b_val = b.data[broadcastedFlatIdx(b, idx, out_shape.len)];
        result.data[flat_out] = op(a_val, b_val);
    }

    return result;
}

fn f32Add(a: f32, b: f32) f32 {
    return a + b;
}
fn f32Sub(a: f32, b: f32) f32 {
    return a - b;
}
fn f32Mul(a: f32, b: f32) f32 {
    return a * b;
}
fn f32Div(a: f32, b: f32) f32 {
    return a / b;
}
fn f32Pow(a: f32, b: f32) f32 {
    return std.math.pow(f32, a, b);
}

pub fn incInPlace(a: *Tensor) void {
    for (a.data) |*val| val.* += 1.0;
}

pub fn add(a: Tensor, b: Tensor, alloc: Allocator) !Tensor {
    return broadcastApply(&a, &b, alloc, f32Add);
}
pub fn sub(a: Tensor, b: Tensor, alloc: Allocator) !Tensor {
    return broadcastApply(&a, &b, alloc, f32Sub);
}
pub fn mul(a: Tensor, b: Tensor, alloc: Allocator) !Tensor {
    return broadcastApply(&a, &b, alloc, f32Mul);
}
pub fn pow(a: Tensor, b: Tensor, alloc: Allocator) !Tensor {
    return broadcastApply(&a, &b, alloc, f32Pow);
}
pub fn div(a: Tensor, b: Tensor, alloc: Allocator) !Tensor {
    return broadcastApply(&a, &b, alloc, f32Div);
}

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

pub fn zerosLike(ref: Tensor, alloc: Allocator) !Tensor {
    const cloned = try ref.clone(alloc);
    for (cloned.data) |*val| val.* = 0;
    return cloned;
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

pub fn sumAll(self: *const Tensor, alloc: Allocator) !Tensor {
    var result = try makeTensor(alloc, &[0]usize{});

    for (self.data) |val| result.data[0] += val;

    return result;
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

pub fn addInPlace(self: *Tensor, b: Tensor) !void {
    if (!std.mem.eql(usize, self.shape, b.shape))
        return error.OperandSizesDoNotAgree;

    for (self.data, 0..) |*a_val, i|
        a_val.* += b.data[i];
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

test "broadcast scalar against matrix" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var A: Tensor = try .makeTensor(alloc, &[2]usize{ 2, 3 });
    A.setMany(&[_]f32{ 1, 2, 3, 4, 5, 6 });

    var S: Tensor = try .makeTensor(alloc, &[0]usize{});
    S.data[0] = 2.0;

    const C = try A.add(S, alloc);
    try std.testing.expectEqualSlices(usize, &[_]usize{ 2, 3 }, C.shape);
    try std.testing.expectEqualSlices(f32, &[_]f32{ 3, 4, 5, 6, 7, 8 }, C.data);
}

test "broadcast row vector against matrix" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var A: Tensor = try .makeTensor(alloc, &[2]usize{ 2, 3 });
    A.setMany(&[_]f32{ 1, 2, 3, 4, 5, 6 });

    var B: Tensor = try .makeTensor(alloc, &[2]usize{ 1, 3 });
    B.setMany(&[_]f32{ 10, 20, 30 });

    const C = try A.add(B, alloc);
    try std.testing.expectEqualSlices(usize, &[_]usize{ 2, 3 }, C.shape);
    try std.testing.expectEqualSlices(f32, &[_]f32{ 11, 22, 33, 14, 25, 36 }, C.data);
}

test "sum" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var A: Tensor = try .makeTensor(alloc, &[2]usize{ 2, 3 });
    A.setMany(&[_]f32{ 1, 2, 3, 4, 5, 6 });

    const D = try A.sumAll(alloc);
    try std.testing.expectEqualSlices(usize, &[_]usize{}, D.shape);
    try std.testing.expectEqualSlices(f32, &[_]f32{1 + 2 + 3 + 4 + 5 + 6}, D.data);
}
