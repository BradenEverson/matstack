//! Unary Operation Nodes

const std = @import("std");

const Node = @import("../node.zig");

node: Node.NodeId,
op: UnaryOp,

const Self = @This();

pub const UnaryOp = enum {
    sum,
    transpose,
    softmax,
    relu,
};
