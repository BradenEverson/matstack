//! The core matstack VM

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Tensor = @import("tensor.zig");
pub const Operand = @import("operand.zig").Operand;
pub const Instruction = @import("instruction.zig").Instruction;

/// Maximum operands that can be on the stack at a time
pub const MAX_STACK_SIZE: usize = 512;
pub const SCRATCH_SIZE: usize = 256;

pub const OperandStack = [MAX_STACK_SIZE]Operand;

pub fn parseConstantPool(alloc: Allocator, cpool_bytes: []const u8) ![]const Tensor {
    _ = alloc;
    _ = cpool_bytes;
}

pub const VirtualMachine = struct {
    constant_pool: []const Tensor,
    stack: OperandStack,
    instructions: []const Instruction,
    scratch_area: [SCRATCH_SIZE]Operand,
};

test {
    _ = @import("tensor.zig");
    _ = @import("operand.zig");
}
