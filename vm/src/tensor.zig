//! Tensors are the core value of matstack, so we should probably design 'em pretty well

const std = @import("std");
const Allocator = std.mem.Allocator;

const Tensor = @This();

pub const TensorError = error{
    InvalidShapeForOp,
    OperandSizesDoNotAgree,
};

/// An UNOWNED look into the data
/// the VM truly owns this in an arena
/// like structure
///
/// when constructed by being passed into the `makeTensor`
/// function, it should most definitely be an arena
/// allocator
///
/// We trust shape fully with the dimensions of this data
data: []f32,

/// The shape in row-first order
///
/// this is also unowned, deinit
/// will not clear it
shape: []usize,

/// Offset for slices into existing tensors
offset: usize = 0,

/// for each dimension along the shape,
/// how many elements we move forward
/// flatly to get to the next index.
/// ex: in a 2x3 matrix, strides would
/// be [3, 1] to move down a row or col
///
/// this is also unowned, deinit
/// will not clear it
strides: []usize,

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
