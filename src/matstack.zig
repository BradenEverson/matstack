//! The core matstack VM

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Tensor = @import("tensor.zig");
pub const OperandStack = @import("stack.zig");
pub const Operand = @import("operand.zig").Operand;
pub const Instruction = @import("instruction.zig").Instruction;

/// How many tensor slots there are for
/// working area memory
pub const SCRATCH_SIZE: usize = 256;

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
    _ = @import("instruction.zig");
    _ = @import("stack.zig");
}
