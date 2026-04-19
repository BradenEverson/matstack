//! Translation from AST to VM Bytecode!

const std = @import("std");
const parser = @import("parser.zig");
const tokenizer = @import("tokenizer.zig");
const matstack = @import("matstack");

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
    /// TODO: We need to validate that a literal
    /// provided does not have malformed dimensions
    tensors: std.ArrayList(parser.Literal) = .empty,

    instructions: std.ArrayList(matstack.Instruction) = .empty,

    pub fn deinit(self: *VmIR, alloc: std.mem.Allocator) void {
        self.slotstack.reused.deinit(alloc);
        self.instructions.deinit(alloc);
        self.variable_allocations.deinit(alloc);
        self.tensors.deinit(alloc);
    }

    pub fn fromAst(self: *VmIR, alloc: std.mem.Allocator, ast: []*const parser.Expr) !void {
        for (ast) |expr| {
            try self.evalExpr(alloc, expr);
        }
    }

    pub fn evalExpr(self: *VmIR, alloc: std.mem.Allocator, expr: *const parser.Expr) !void {
        switch (expr.*) {
            .binary_op => |b| {
                try self.evalExpr(alloc, b.left);
                try self.evalExpr(alloc, b.right);

                const cmd = opToCmd(b.op);
                try self.instructions.append(alloc, .{ .cmd = cmd });
            },

            .unary_op => |u| {
                try self.evalExpr(alloc, u.expr);

                const cmd = keywordToCmd(u.op);
                try self.instructions.append(alloc, .{ .cmd = cmd });
            },

            .assignment => |a| {
                try self.evalExpr(alloc, a.val);

                // TODO: here maybe we check all future instructions for
                // variables that are never referenced again and drop them
                // from the slot if so to free up space!
                const slot = try self.slotstack.pop();

                try self.variable_allocations.put(alloc, a.name, slot);
                try self.instructions.append(alloc, .{ .cmd = .load_i, .extra = slot });
            },

            .variable => |v| {
                if (self.variable_allocations.get(v)) |slot| {
                    try self.instructions.append(alloc, .{ .cmd = .store_i, .extra = slot });
                } else {
                    return error.UsedBeforeDefine;
                }
            },

            .literal => |l| {
                // TODO: we need some way of hashing these tensor literals
                // to see if they're already in the constant pool. Right now,
                // if some arbitrary literal is used everywhere then the cpool
                // will go crazy
                //
                // For now tho let's just do it easy, quick and dirty
                try self.tensors.append(alloc, l);
                const cpool_idx = self.tensors.items.len - 1;

                try self.instructions.append(alloc, .{
                    .cmd = .load_const,
                    .extra = @truncate(cpool_idx),
                });
            },
        }
    }
};

fn keywordToCmd(op: tokenizer.Keyword) matstack.Instruction.Command {
    return switch (op) {
        .zeros_like => unreachable, // TODO, should this be runtime or comptime?
        .rand => unreachable, // TODO, this will be comptime
        .debug => .debug_print,
        .softmax => .softmax,
        .relu => .relu,
        .cross_entropy => .cross_entropy,
        .ln => .log,
        .exp => .exp,
    };
}

fn opToCmd(op: parser.BinaryOp) matstack.Instruction.Command {
    return switch (op) {
        .add => .add,
        .div => .div,
        .matmul => .matmul,
        .mul => .mul,
        .sub => .sub,
    };
}
