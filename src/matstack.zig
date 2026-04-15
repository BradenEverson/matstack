//! The core matstack VM

const std = @import("std");

pub const Tensor = @import("tensor.zig");
pub const Operand = @import("operand.zig").Operand;

pub const OperandStack = std.ArrayList(Operand);

pub const VirtualMachine = struct {
    constant_pool: []const Tensor,
    gp_registers: [32]Tensor = undefined,
    stack: OperandStack,
};

test {
    _ = @import("tensor.zig");
    _ = @import("operand.zig");
}
