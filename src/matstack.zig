//! The core matstack VM

const std = @import("std");

pub const Tensor = @import("tensor.zig");
pub const Operand = @import("operand.zig").Operand;

pub const OperandStack = std.ArrayList(Operand);

pub const NUM_REGISTERS: usize = 32;

pub fn parseConstantPool(cpool_bytes: []const u8) []const Tensor {
    _ = cpool_bytes;
}

pub const VirtualMachine = struct {
    constant_pool: []const Tensor,
    gp_registers: [NUM_REGISTERS]Tensor = undefined,
    stack: OperandStack,
};

test {
    _ = @import("tensor.zig");
    _ = @import("operand.zig");
}
