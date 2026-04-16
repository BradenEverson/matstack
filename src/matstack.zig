//! The core matstack VM

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Tensor = @import("tensor.zig");
pub const Operand = @import("operand.zig").Operand;
pub const Instruction = @import("instruction.zig").Instruction;

/// Maximum operands that can be on the stack at a time
pub const MAX_STACK_SIZE: usize = 512;

/// How many tensor slots there are for
/// working area memory
pub const SCRATCH_SIZE: usize = 256;

pub const StackError = error{
    StackFull,
    StackEmpty,
};

pub const OperandStack = struct {
    sp: usize = 0,
    stack: [MAX_STACK_SIZE]Operand,

    pub fn push(stack: *OperandStack, val: Operand) !void {
        if (stack.sp >= MAX_STACK_SIZE) return error.StackFull;
        stack.stack[stack.sp] = val;
        stack.sp += 1;
    }

    pub fn pop(stack: *OperandStack) !Operand {
        if (stack.sp == 0) return error.StackEmpty;
        stack.sp -= 1;

        return stack.stack[stack.sp];
    }
};

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
