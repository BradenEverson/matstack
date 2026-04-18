//! Translation from AST to VM Bytecode!

const std = @import("std");
const parser = @import("parser.zig");
const matstack = @import("matstack");

pub const CompileError = error{
    /// when a provided tensor literal is inconsistently sized, such as
    /// [[1,2,3], [1,2], [1,2,3]]
    MalformedTensor,
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

    instruction: std.ArrayList(matstack.Instruction) = .empty,

    pub fn fromAst(alloc: std.mem.Allocator, ast: []const parser.Expr) !void {
        _ = alloc;
        _ = ast;
    }
};
