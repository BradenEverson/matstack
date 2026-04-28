//! Binary Op

const std = @import("std");
const Node = @import("../node.zig");

left: Node.NodeId,
right: Node.NodeId,

op: BinaryOp,

const Self = @This();

pub const BinaryOp = enum {
    add,
    sub,
    mul,
    matmul,
    mse,
    cross_entropy,
};
