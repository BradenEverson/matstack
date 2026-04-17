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

pub const VmError = error{
    NoMoreInstructions,
};

pub const VirtualMachine = struct {
    constant_pool: []const Tensor,
    stack: OperandStack = .{},

    instructions: []const Instruction,
    pc: usize = 0,

    scratch_area: [SCRATCH_SIZE]Operand = undefined,

    pub fn step(vm: *VirtualMachine, alloc: Allocator) !void {
        if (vm.pc >= vm.instructions.len)
            return error.NoMoreInstructions;

        const instr = vm.instructions[vm.pc];
        const cmd = instr.cmd;
        const extra = instr.extra;

        vm.pc += 1;

        switch (cmd) {
            .load_const => {
                const cpool_idx = @as(usize, extra);
                const res = try vm.constant_pool[cpool_idx].clone(alloc);

                try vm.stack.push(res);
            },

            .matmul => {
                var rhs = try vm.stack.pop();
                defer rhs.deinit(alloc);
                var lhs = try vm.stack.pop();
                defer lhs.deinit(alloc);

                const res = try lhs.matmul(rhs, alloc);
                try vm.stack.push(res);
            },

            .add => {
                var rhs = try vm.stack.pop();
                defer rhs.deinit(alloc);
                var lhs = try vm.stack.pop();

                try lhs.addInPlace(rhs);
                try vm.stack.push(lhs);
            },

            .transpose => {
                var res = try vm.stack.pop();
                try res.transposeMatInPlace();

                try vm.stack.push(res);
            },

            .load_i => {
                const res = try vm.stack.peek();
                const idx = @as(usize, extra);

                vm.scratch_area[idx] = try res.clone(alloc);
            },

            .store_i => {
                const idx = @as(usize, extra);
                const res = try vm.scratch_area[idx].clone(alloc);

                try vm.stack.push(res);
            },

            .relu => {
                var res = try vm.stack.pop();
                res.inPlaceRelu();

                try vm.stack.push(res);
            },

            .branch_always => {
                const offset: i8 = @bitCast(extra);
                vm.pc = @intCast(@as(i64, @intCast(vm.pc)) + offset);
            },

            else => {}, // TODO
        }
    }
};

test "simple matmul" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();

    var A: Tensor = try .makeTensor(arena.allocator(), &[2]usize{ 2, 3 });
    var B: Tensor = try .makeTensor(arena.allocator(), &[2]usize{ 3, 2 });

    A.setMany(&[_]f32{ 1, 2, 1, 0, 1, 0 });
    B.setMany(&[_]f32{ 2, 5, 6, 7, 1, 8 });

    const constant_pool = &[_]Tensor{ A, B };
    const instructions = &[_]Instruction{
        .{ .cmd = .load_const, .extra = 0 }, // LOAD A
        .{ .cmd = .load_const, .extra = 1 }, // LOAD B
        .{ .cmd = .matmul }, // MATMUL
    };

    var vm: VirtualMachine = .{
        .constant_pool = constant_pool,
        .instructions = instructions,
    };

    try vm.step(arena.allocator());
    try vm.step(arena.allocator());
    try vm.step(arena.allocator());

    const C = try vm.stack.pop();

    try std.testing.expectEqualSlices(usize, &[_]usize{ 2, 2 }, C.shape);
    try std.testing.expectEqualSlices(f32, &[_]f32{ 15, 27, 6, 7 }, C.data);
}

test {
    _ = @import("tensor.zig");
    _ = @import("operand.zig");
    _ = @import("instruction.zig");
    _ = @import("stack.zig");
}
