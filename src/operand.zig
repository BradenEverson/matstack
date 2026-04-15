//! Operand Union

const Tensor = @import("tensor.zig");

pub const Operand = union(enum) {
    tensor: Tensor,
};
