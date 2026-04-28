//! A node in the graph
//! Node definition

const std = @import("std");
const Allocator = std.mem.Allocator;

const Tensor = @import("matstack").tensor.Tensor;

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
    // binary_op: Binary,
    // unary_op: Unary,
};

ty: NodeType,

const Self = @This();

pub fn deinit(self: *Self, alloc: Allocator) void {
    self.ty.deinit(alloc);
}
