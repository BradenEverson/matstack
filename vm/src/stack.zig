//! The Operand Stack!

pub const Operand = @import("tensor.zig");

/// Maximum operands that can be on the stack at a time
pub const MAX_STACK_SIZE: usize = 512;

pub const StackError = error{
    StackFull,
    StackEmpty,
};

sp: usize = 0,
stack: [MAX_STACK_SIZE]Operand,

const Self = @This();

pub fn push(stack: *Self, val: Operand) !void {
    if (stack.sp >= MAX_STACK_SIZE) return error.StackFull;
    stack.stack[stack.sp] = val;
    stack.sp += 1;
}

pub fn pop(stack: *Self) !Operand {
    if (stack.sp == 0) return error.StackEmpty;
    stack.sp -= 1;

    return stack.stack[stack.sp];
}
