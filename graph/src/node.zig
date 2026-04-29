//! A node in the graph
//! Node definition

const std = @import("std");
const Allocator = std.mem.Allocator;

const Instruction = @import("matstack").Instruction;

const Tensor = @import("matstack").Tensor;

pub const NodeId = packed struct { idx: usize };

pub const NodeType = union(enum) {
    // an input tensor, will pop these inputs off of the stack
    input: usize,
    // A constant Tensor
    constant: Tensor,
    // Some operation node that depends on previous nodes
    operation: NodeOperation,

    pub fn deinit(self: *NodeType, alloc: std.mem.Allocator) void {
        switch (self.*) {
            .constant => |*t| t.deinit(alloc),
            else => {},
        }
    }
};

pub const NodeOperation = union(enum) {
    linear: struct { W: NodeId, x: NodeId, b: NodeId },

    add: struct { A: NodeId, B: NodeId },
    regularization: struct { epsilon: f32, W: NodeId },
    cross_entropy: struct { v: NodeId, y: NodeId },
    mse: struct { v: NodeId, y: NodeId },

    sum: struct { W: NodeId },
    relu: struct { x: NodeId },
    transpose: struct { X: NodeId },
    softmax: struct { x: NodeId },
};

ty: NodeType,

const Self = @This();

pub fn deinit(self: *Self, alloc: Allocator) void {
    self.ty.deinit(alloc);
}

pub fn eval(self: *Self, alloc: Allocator) !Tensor {
    _ = self;
    _ = alloc;
}

pub fn compile(self: *Self, alloc: Allocator, instr: *std.ArrayList(Instruction)) !void {
    _ = self;
    _ = alloc;
    _ = instr;
}
