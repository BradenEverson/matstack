//! Instruction format and binary translation

pub const Command = enum(u8) {
    // Data processing
    nop,
    add,
    mul,
    matmul,

    // Memory
    load_const,

    // Branching
    branch_always,
};

cmd: Command = .nop,
extra: u8 = 0,
