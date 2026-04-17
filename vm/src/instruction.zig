//! Instruction format and binary translation

pub const Command = enum(u8) {
    // Data processing
    nop,
    add,
    sub,
    mul,
    matmul,
    transpose,
    relu,

    // Memory
    load_const,
    /// Clones and loads the top tensor to
    /// a provided index into the scratch
    /// area
    load_i,
    /// Grabs and pushes the tensor at a provided
    /// index in the scratch area onto the stack
    store_i,

    // Branching
    branch_always,
    branch_eq,
    branch_ne,

    // Debug
    debug_print,
};

cmd: Command = .nop,
extra: u8 = 0,
