//! The core matstack VM

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Tensor = @import("tensor.zig");
pub const OperandStack = @import("stack.zig");
pub const Instruction = @import("instruction.zig");

pub const Operand = Tensor;

/// How many tensor slots there are for
/// working area memory
pub const SCRATCH_SIZE: usize = 256;

pub fn parseConstantPool(
    alloc: Allocator,
    cpool_bytes: []const u8,
) ![]const Tensor {
    _ = alloc;
    _ = cpool_bytes;
}

pub const VirtualMachine = struct {
    constant_pool: []const Tensor,
    stack: OperandStack,

    instructions: []const Instruction,
    pc: usize = 0,

    scratch_area: [SCRATCH_SIZE]Operand,

    pub fn step(vm: *VirtualMachine, alloc: Allocator) !void {
        const cmd, const extra: Instruction = vm.instructions[vm.pc];

        switch (cmd) {
            .load_const => {
                const cpool_idx = @as(usize, extra);
                try vm.stack.push(vm.constant_pool[cpool_idx]);
            },

            .matmul => {
                const rhs = try vm.stack.pop();
                const lhs = try vm.stack.pop();

                const res = lhs.matmul(rhs, alloc);
                try vm.stack.push(res);
            },

            .transpose => {
                var res = try vm.stack.pop();
                res.transposeMatInPlace();

                try vm.stack.push(res);
            },

            _ => {}, // TODO
        }
    }
};

test {
    _ = @import("tensor.zig");
    _ = @import("operand.zig");
    _ = @import("instruction.zig");
    _ = @import("stack.zig");
}
