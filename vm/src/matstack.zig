//! The core matstack VM

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Tensor = @import("tensor.zig");
pub const OperandStack = @import("stack.zig");
pub const Instruction = @import("instruction.zig");
pub const Command = Instruction.Command;

pub const Operand = Tensor;

/// How many tensor slots there are for
/// working area memory
pub const SCRATCH_SIZE: usize = 256;

pub fn parseConstantPool(
    alloc: Allocator,
    tensor_count: usize,
    cpool_bytes: []const u8,
) ![]const Tensor {
    const constant_pool = try alloc.alloc(Tensor, tensor_count);
    errdefer alloc.free(constant_pool);
    var rest = cpool_bytes;

    for (constant_pool) |*constant| {
        constant.*, rest = try Tensor.fromBytes(alloc, rest);
        errdefer alloc.free(constant.deinit(alloc));
    }

    return constant_pool;
}

pub const VmError = error{
    MalformedInstructionBytes,
};

pub const VirtualMachine = struct {
    constant_pool: []const Tensor,
    stack: OperandStack = .{},

    instructions: []const Instruction,
    pc: usize = 0,

    scratch_area: [SCRATCH_SIZE]Operand = undefined,

    pub fn tryParse(alloc: Allocator, bytes: []const u8) !VirtualMachine {
        var rest = bytes;

        // Parse the header
        // one 4-byte length of cpool in bytes
        // one 4-byte length of cpool in tensors
        const cpool_bytes = std.mem.readInt(u32, &[4]u8{
            rest[0],
            rest[1],
            rest[2],
            rest[3],
        }, .little);
        rest = rest[4..];

        const cpool_tensors = std.mem.readInt(u32, &[4]u8{
            rest[0],
            rest[1],
            rest[2],
            rest[3],
        }, .little);
        rest = rest[4..];

        // Parse the constant pool :D

        const cpool = try parseConstantPool(alloc, cpool_tensors, rest[0..cpool_bytes]);
        errdefer alloc.free(cpool);

        rest = rest[cpool_bytes..];

        // The rest of the bytes are 2-byte instruction pairs
        // let's make sure the rest actually is 2-byte pairs
        if (rest.len % 2 != 0)
            return error.MalformedInstructionBytes;

        const instr_count = rest.len / 2;
        const instructions = try alloc.alloc(Instruction, instr_count);
        errdefer alloc.free(instructions);

        for (instructions) |*instr| {
            const cmd_byte = rest[0];
            const extra_byte = rest[1];

            instr.* = .{
                .cmd = @enumFromInt(cmd_byte),
                .extra = extra_byte,
            };

            rest = rest[2..];
        }

        return .{
            .constant_pool = cpool,
            .instructions = instructions,
        };
    }

    pub fn step(vm: *VirtualMachine, alloc: Allocator) !bool {
        if (vm.pc >= vm.instructions.len)
            return true;

        const instr = vm.instructions[vm.pc];
        const cmd = instr.cmd;
        const extra = instr.extra;

        vm.pc += 1;

        switch (cmd) {
            .LOAD_CONST => {
                const cpool_idx = @as(usize, extra);
                const res = try vm.constant_pool[cpool_idx].clone(alloc);

                try vm.stack.push(res);
            },

            .MATMUL => {
                var rhs = try vm.stack.pop();
                defer rhs.deinit(alloc);
                var lhs = try vm.stack.pop();
                defer lhs.deinit(alloc);

                const res = try lhs.matmul(rhs, alloc);
                try vm.stack.push(res);
            },

            .LT => {
                var rhs = try vm.stack.pop();
                defer rhs.deinit(alloc);
                var lhs = try vm.stack.pop();
                defer lhs.deinit(alloc);

                const res = try lhs.lt(rhs, alloc);
                try vm.stack.push(res);
            },

            .GT => {
                var rhs = try vm.stack.pop();
                defer rhs.deinit(alloc);
                var lhs = try vm.stack.pop();
                defer lhs.deinit(alloc);

                const res = try lhs.gt(rhs, alloc);
                try vm.stack.push(res);
            },

            .ADD => {
                var rhs = try vm.stack.pop();
                defer rhs.deinit(alloc);
                var lhs = try vm.stack.pop();
                defer lhs.deinit(alloc);

                const res = try lhs.add(rhs, alloc);
                try vm.stack.push(res);
            },

            .SOFTMAX => {
                var on = try vm.stack.pop();
                defer on.deinit(alloc);

                const res = try on.softmax(alloc);
                try vm.stack.push(res);
            },

            .CROSS_ENTROPY => {
                var rhs = try vm.stack.pop();
                defer rhs.deinit(alloc);
                var lhs = try vm.stack.pop();
                defer lhs.deinit(alloc);

                const res = try lhs.crossEntropyLoss(rhs, alloc);
                try vm.stack.push(res);
            },

            .SUM_REDUCE => {
                var on = try vm.stack.pop();
                defer on.deinit(alloc);

                const res = try on.sumReduce(alloc, @as(usize, extra));
                try vm.stack.push(res);
            },

            .INC => {
                var val = try vm.stack.peek();
                val.incInPlace();
            },

            .SUB => {
                var rhs = try vm.stack.pop();
                defer rhs.deinit(alloc);
                var lhs = try vm.stack.pop();
                defer lhs.deinit(alloc);

                const res = try lhs.sub(rhs, alloc);
                try vm.stack.push(res);
            },

            .DIV => {
                var rhs = try vm.stack.pop();
                defer rhs.deinit(alloc);
                var lhs = try vm.stack.pop();
                defer lhs.deinit(alloc);

                const res = try lhs.div(rhs, alloc);
                try vm.stack.push(res);
            },

            .MUL => {
                var rhs = try vm.stack.pop();
                defer rhs.deinit(alloc);
                var lhs = try vm.stack.pop();
                defer lhs.deinit(alloc);

                const res = try lhs.mul(rhs, alloc);
                try vm.stack.push(res);
            },

            .POW => {
                var rhs = try vm.stack.pop();
                defer rhs.deinit(alloc);
                var lhs = try vm.stack.pop();
                defer lhs.deinit(alloc);

                const res = try lhs.pow(rhs, alloc);
                try vm.stack.push(res);
            },

            .SUM => {
                var on = try vm.stack.pop();
                defer on.deinit(alloc);

                const res = try on.sumAll(alloc);
                try vm.stack.push(res);
            },

            .SLICE => {
                const slice_info = try vm.stack.pop();
                var slicing = try vm.stack.pop();
                defer slicing.deinit(alloc);

                const res = try slicing.sliceRanges(
                    alloc,
                    slice_info,
                );

                try vm.stack.push(res);
            },

            .RELU => {
                var res = try vm.stack.pop();
                res.inPlaceRelu();

                try vm.stack.push(res);
            },

            .TRANSPOSE => {
                var res = try vm.stack.pop();
                try res.transposeMatInPlace();

                try vm.stack.push(res);
            },

            .ZEROS_LIKE => {
                var res = try vm.stack.pop();
                defer res.deinit(alloc);

                try vm.stack.push(try res.zerosLike(alloc));
            },

            .LOAD_I => {
                var res = try vm.stack.pop();
                defer res.deinit(alloc);

                const idx = @as(usize, extra);

                vm.scratch_area[idx] = try res.clone(alloc);
            },

            .CLONE_I => {
                const res = try vm.stack.peek();
                const idx = @as(usize, extra);

                vm.scratch_area[idx] = try res.clone(alloc);
            },

            .STORE_I => {
                const idx = @as(usize, extra);
                const res = try vm.scratch_area[idx].clone(alloc);

                try vm.stack.push(res);
            },

            .BRANCH_ALWAYS => {
                const pc = @as(usize, extra);
                vm.pc = pc;
            },

            .BRANCH_EQ => {
                var cmp = try vm.stack.pop();
                defer cmp.deinit(alloc);

                if (cmp.isZero()) {
                    const pc = @as(usize, extra);
                    vm.pc = pc;
                }
            },

            .BRANCH_NE => {
                var cmp = try vm.stack.pop();
                defer cmp.deinit(alloc);

                if (!cmp.isZero()) {
                    const pc = @as(usize, extra);
                    vm.pc = pc;
                }
            },

            .DEBUG_PRINT => {
                const top = try vm.stack.pop();
                std.debug.print("{any}\n", .{top});
            },

            else => {
                std.debug.print("TODO: {any}\n", .{cmd});
                @panic("TODO!!!\n");
            },
        }

        return false;
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
        .{ .cmd = .LOAD_CONST, .extra = 0 }, // LOAD A
        .{ .cmd = .LOAD_CONST, .extra = 1 }, // LOAD B
        .{ .cmd = .MATMUL }, // MATMUL
    };

    var vm: VirtualMachine = .{
        .constant_pool = constant_pool,
        .instructions = instructions,
    };

    while (!(try vm.step(arena.allocator()))) {}

    const C = try vm.stack.pop();

    try std.testing.expectEqualSlices(usize, &[_]usize{ 2, 2 }, C.shape);
    try std.testing.expectEqualSlices(f32, &[_]f32{ 15, 27, 6, 7 }, C.data);
}

test "parse an entire VM then execute" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();

    const bytes = &[_]u8{
        0x42, 0x00, 0x00, 0x00, // cpool bytes
        0x02, 0x00, 0x00, 0x00, // cpool tensors

        // Constant A
        2, // n_dims
        0x02, 0x00, 0x00, 0x00, // 2 rows
        0x03, 0x00, 0x00, 0x00, // 3 cols
        0x00, 0x00, 0x80, 0x3f, // 1
        0x00, 0x00, 0x00, 0x40, // 2
        0x00, 0x00, 0x80, 0x3f, // 1
        0x00, 0x00, 0x00, 0x00, // 0
        0x00, 0x00, 0x80, 0x3f, // 1
        0x00, 0x00, 0x00, 0x00, // 0

        // Constant B
        2, // n_dims
        0x03, 0x00, 0x00, 0x00, // 3 rows
        0x02, 0x00, 0x00, 0x00, // 2 cols
        0x00, 0x00, 0x00, 0x40, // 2
        0x00, 0x00, 0xa0, 0x40, // 5
        0x00, 0x00, 0xc0, 0x40, // 6
        0x00, 0x00, 0xe0, 0x40, // 7
        0x00, 0x00, 0x80, 0x3f, // 1
        0x00, 0x00, 0x00, 0x41, // 8

        // Instructions
        @intFromEnum(Command.LOAD_CONST), 0x00, // LOAD A
        @intFromEnum(Command.LOAD_CONST), 0x01, // LOAD B
        @intFromEnum(Command.MATMUL), 0x00, // MATMUL
    };

    var vm = try VirtualMachine.tryParse(arena.allocator(), bytes);
    while (!(try vm.step(arena.allocator()))) {}

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
