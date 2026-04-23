//! Translation from AST to VM Bytecode!

const std = @import("std");
const parser = @import("parser.zig");
const tokenizer = @import("tokenizer.zig");
const matstack = @import("matstack");

var prng: ?std.Random.DefaultPrng = null;

fn getRand(io: std.Io) std.Random {
    if (prng) |*r| {
        return r.random();
    } else {
        prng = .init(blk: {
            var seed: u64 = undefined;
            io.random(std.mem.asBytes(&seed));
            break :blk seed;
        });
        return prng.?.random();
    }
}

pub const CompileError = error{
    /// when a provided tensor literal is inconsistently sized, such as
    /// [[1,2,3], [1,2], [1,2,3]]
    MalformedTensor,
    /// When a variable is used before initialized
    UseBeforeDefine,
};

/// A nice little structure for maintaining free
/// slots in the scratch area for variable allocation.
///
/// Probably overkill for now but hey it's fun
pub const SlotStack = struct {
    bottom: u8 = 0,
    reused: std.ArrayList(u8) = .empty,

    const SlotStackError = error{
        NoFreeSlots,
    };

    pub fn pop(stack: *SlotStack) !u8 {
        if (stack.reused.items.len != 0) {
            return stack.reused.pop().?;
        }

        stack.bottom += 1;
        return stack.bottom - 1;
    }
};

pub const VmIR = struct {
    /// Allocations into the scratch area for variables to be stored
    variable_allocations: std.StringHashMapUnmanaged(u8) = .empty,
    slotstack: SlotStack = .{},

    /// The constant pool.
    tensors: std.ArrayList(matstack.Tensor) = .empty,

    instructions: std.ArrayList(matstack.Instruction) = .empty,

    pub fn deinit(self: *VmIR, alloc: std.mem.Allocator) void {
        self.slotstack.reused.deinit(alloc);
        self.instructions.deinit(alloc);
        self.variable_allocations.deinit(alloc);
        self.tensors.deinit(alloc);
    }

    pub fn fromAst(
        self: *VmIR,
        io: std.Io,
        alloc: std.mem.Allocator,
        ast: []*const parser.Expr,
    ) !void {
        for (ast) |expr| {
            try self.evalExpr(io, alloc, expr);
        }
    }

    pub fn evalExpr(
        self: *VmIR,
        io: std.Io,
        alloc: std.mem.Allocator,
        expr: *const parser.Expr,
    ) !void {
        switch (expr.*) {
            .binary_op => |b| {
                try self.evalExpr(io, alloc, b.left);
                try self.evalExpr(io, alloc, b.right);

                const cmd = opToCmd(b.op);
                try self.instructions.append(alloc, .{ .cmd = cmd });
            },

            .unary_op => |u| {
                try self.evalExpr(io, alloc, u.expr);

                const cmd = keywordToCmd(u.op);
                try self.instructions.append(alloc, cmd);
            },

            .rand_tensor => |shape| {
                const tensor = try matstack.Tensor.makeTensor(
                    alloc,
                    shape.items[0..shape.items.len],
                );

                var rand = getRand(io);

                for (tensor.data) |*val| {
                    const r = rand.float(f32);
                    val.* = r;
                }

                try self.tensors.append(alloc, tensor);

                try self.instructions.append(alloc, .{
                    .cmd = .LOAD_CONST,
                    .extra = @truncate(self.tensors.items.len - 1),
                });
            },

            .assignment => |a| {
                try self.evalExpr(io, alloc, a.val);

                // TODO: here maybe we check all future instructions for
                // variables that are never referenced again and drop them
                // from the slot if so to free up space!
                const slot = self.variable_allocations.get(a.name) orelse try self.slotstack.pop();

                try self.variable_allocations.put(alloc, a.name, slot);
                try self.instructions.append(
                    alloc,
                    .{ .cmd = .LOAD_I, .extra = slot },
                );
            },

            .loop => |l| {
                // Create loop variable
                const start = try matstack.Tensor.makeTensor(alloc, &[0]usize{});
                start.data[0] = @floatFromInt(l.from);
                const start_idx = try self.registerTensor(alloc, start);

                const end = try matstack.Tensor.makeTensor(alloc, &[0]usize{});
                end.data[0] = @floatFromInt(l.to);
                const end_idx = try self.registerTensor(alloc, end);

                const slot = try self.slotstack.pop();
                try self.variable_allocations.put(alloc, l.counter, slot);

                try self.instructions.append(alloc, .{
                    .cmd = .LOAD_CONST,
                    .extra = @truncate(start_idx),
                });

                try self.instructions.append(alloc, .{
                    .cmd = .LOAD_I,
                    .extra = @truncate(slot),
                });

                const s = self.instructions.items.len;

                // Perform all instructions stored in the block
                for (l.eval.items) |e| {
                    try self.evalExpr(io, alloc, e);
                }

                // Do a comparison on loop variable and end point
                // branch back to start of eval if not equal
                try self.instructions.append(alloc, .{
                    .cmd = .LOAD_CONST,
                    .extra = @truncate(end_idx),
                });
                try self.instructions.append(alloc, .{ .cmd = .STORE_I, .extra = slot });
                try self.instructions.append(alloc, .{ .cmd = .INC });
                try self.instructions.append(alloc, .{ .cmd = .LOAD_I, .extra = slot });
                try self.instructions.append(alloc, .{ .cmd = .STORE_I, .extra = slot });
                try self.instructions.append(alloc, .{ .cmd = .SUB });

                const len_instr = self.instructions.items.len - s;

                const len: u32 = @truncate(len_instr);
                const len_i: isize = @intCast(len + 1);
                const jump: isize = 0 - len_i;
                const jump_i8: i8 = @truncate(jump);
                const jump_u8: u8 = @bitCast(jump_i8);
                try self.instructions.append(alloc, .{ .cmd = .BRANCH_NE, .extra = jump_u8 });

                // when we're done, counter variable is out of scope!
                try self.slotstack.reused.append(alloc, slot);
                _ = self.variable_allocations.remove(l.counter);
            },

            .variable => |v| {
                if (self.variable_allocations.get(v)) |slot| {
                    try self.instructions.append(alloc, .{ .cmd = .STORE_I, .extra = slot });
                } else {
                    std.debug.print("{s}\n", .{v});
                    return error.UsedBeforeDefine;
                }
            },

            .literal => |l| {
                const tensor = try literalToTensor(alloc, l);

                const cpool_idx = try self.registerTensor(alloc, tensor);

                try self.instructions.append(alloc, .{
                    .cmd = .LOAD_CONST,
                    .extra = @truncate(cpool_idx),
                });
            },
        }
    }

    fn registerTensor(
        self: *VmIR,
        alloc: std.mem.Allocator,
        tensor: matstack.Tensor,
    ) !usize {
        var cpool_idx = self.tensors.items.len;
        if (self.findTensor(tensor)) |past_idx| {
            cpool_idx = past_idx;
        } else {
            try self.tensors.append(alloc, tensor);
        }

        return cpool_idx;
    }

    pub fn findTensor(self: *const VmIR, tensor: matstack.Tensor) ?usize {
        for (self.tensors.items, 0..) |check, idx| {
            if (tensor.equal(check)) {
                return idx;
            }
        }

        return null;
    }

    pub fn toBytes(
        self: *const VmIR,
        alloc: std.mem.Allocator,
        out: *std.ArrayList(u8),
    ) !void {
        // Write out the constant pool

        for (self.tensors.items) |tensor| {
            try tensor.toBytes(alloc, out);
        }

        const len: u32 = @truncate(out.items.len);
        const tensor_len: u32 = @truncate(self.tensors.items.len);

        var bytes: [4]u8 = undefined;
        std.mem.writeInt(u32, &bytes, tensor_len, .little);

        try out.insert(alloc, 0, bytes[3]);
        try out.insert(alloc, 0, bytes[2]);
        try out.insert(alloc, 0, bytes[1]);
        try out.insert(alloc, 0, bytes[0]);

        std.mem.writeInt(u32, &bytes, len, .little);

        try out.insert(alloc, 0, bytes[3]);
        try out.insert(alloc, 0, bytes[2]);
        try out.insert(alloc, 0, bytes[1]);
        try out.insert(alloc, 0, bytes[0]);

        // Begin dumping instructions
        for (self.instructions.items) |instruction| {
            const cmd: u8 = @intFromEnum(instruction.cmd);
            const extra = instruction.extra;

            try out.append(alloc, cmd);
            try out.append(alloc, extra);
        }
    }
};

fn inferShape(
    alloc: std.mem.Allocator,
    literal: parser.Literal,
) ![]usize {
    switch (literal) {
        .number => {
            return alloc.alloc(usize, 0);
        },

        .multidim => |items| {
            const n = items.items.len;

            if (n == 0) {
                const shape = try alloc.alloc(usize, 1);
                shape[0] = 0;
                return shape;
            }

            var child_shape: ?[]usize = null;
            defer if (child_shape) |s| alloc.free(s);

            for (items.items) |item_expr| {
                if (item_expr.* != .literal)
                    return error.MalformedTensor;

                const this_shape = try inferShape(alloc, item_expr.literal);
                defer alloc.free(this_shape);

                if (child_shape == null) {
                    child_shape = try alloc.dupe(usize, this_shape);
                } else {
                    if (!std.mem.eql(usize, child_shape.?, this_shape))
                        return error.MalformedTensor;
                }
            }

            const child = child_shape.?;
            const shape = try alloc.alloc(usize, 1 + child.len);
            shape[0] = n;
            @memcpy(shape[1..], child);
            return shape;
        },
    }
}

fn fillData(
    data: []f32,
    offset: usize,
    literal: parser.Literal,
) CompileError!usize {
    switch (literal) {
        .number => |v| {
            data[offset] = v;
            return offset + 1;
        },
        .multidim => |items| {
            var cursor = offset;
            for (items.items) |item_expr| {
                if (item_expr.* != .literal)
                    return error.MalformedTensor;
                cursor = try fillData(
                    data,
                    cursor,
                    item_expr.literal,
                );
            }
            return cursor;
        },
    }
}

fn literalToTensor(
    alloc: std.mem.Allocator,
    literal: parser.Literal,
) !matstack.Tensor {
    const shape = try inferShape(alloc, literal);
    defer alloc.free(shape);

    var tensor = try matstack.Tensor.makeTensor(alloc, shape);
    errdefer tensor.deinit(alloc);

    _ = try fillData(tensor.data, 0, literal);

    return tensor;
}

fn keywordToCmd(op: tokenizer.Keyword) matstack.Instruction {
    return switch (op) {
        .zeros_like => .{ .cmd = .ZEROS_LIKE },
        .debug => .{ .cmd = .DEBUG_PRINT },
        .softmax => .{ .cmd = .SOFTMAX },
        .relu => .{ .cmd = .RELU },
        .cross_entropy => .{ .cmd = .CROSS_ENTROPY },
        .ln => .{ .cmd = .LOG },
        .exp => .{ .cmd = .EXP },
        .sum => .{ .cmd = .SUM },
        .transpose => .{ .cmd = .TRANSPOSE },
        .sum_cols => .{ .cmd = .SUM_REDUCE, .extra = 1 },
        .rand => unreachable, // Handled at compile time
        .for_kw => unreachable, // not applicable
        .in => unreachable, // not applicable
    };
}

fn opToCmd(op: parser.BinaryOp) matstack.Instruction.Command {
    return switch (op) {
        .gt => .GT,
        .lt => .LT,
        .add => .ADD,
        .div => .DIV,
        .matmul => .MATMUL,
        .mul => .MUL,
        .sub => .SUB,
        .pow => .POW,
    };
}
