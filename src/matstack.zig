//! The core matstack VM

const std = @import("std");

pub const Tensor = @import("tensor.zig");
pub const Operand = @import("operand.zig").Operand;

/// Maximum operands that can be on the stack at a time
pub const MAX_STACK_SIZE: usize = 512;

pub const OperandStack = [MAX_STACK_SIZE]Operand;

pub fn parseConstantPool(cpool_bytes: []const u8) []const Tensor {
    _ = cpool_bytes;
}

pub const VirtualMachine = struct {
    constant_pool: []const Tensor,
    stack: OperandStack,
};

test {
    _ = @import("tensor.zig");
    _ = @import("operand.zig");
}
