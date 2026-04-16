//! Instruction format and binary translation

/// Opcodes similar to the armv4 variants
pub const Opcode = enum(u2) {
    data = 0x00,
    memory = 0x01,
    branch = 0x02,
};

pub const DataCommand = enum(u4) {};

pub const MemoryCommand = enum(u4) {};

pub const BranchCommand = enum(u4) {};
