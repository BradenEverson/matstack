//! Translation from AST to VM Bytecode!

const std = @import("std");
const parser = @import("parser.zig");

pub const TranslationError = error{
    /// when a provided tensor literal is inconsistently sized, such as
    /// [[1,2,3], [1,2], [1,2,3]]
    MalformedTensor,
};

pub const Tensor = struct {
    data: []f32,
    shape: []usize,

    pub fn makeTensor(alloc: std.mem.Allocator, shape: []const usize) !Tensor {
        const shapeOwned = try alloc.dupe(usize, shape);
        errdefer alloc.free(shapeOwned);

        var n: usize = 1;
        for (shape) |s| n *= s;

        const data = try alloc.alloc(f32, n);

        return .{
            .data = data,
            .shape = shapeOwned,
        };
    }

    pub fn fromLiteral(alloc: std.mem.Allocator, literal: parser.Literal) !Tensor {
        switch (literal) {
            .number => |n| {
                const tensor = try Tensor.makeTensor(alloc, &[_]usize{1});
                tensor.data[0] = n;

                return tensor;
            },
            else => error.MalformedTensor,
        }
    }
};
