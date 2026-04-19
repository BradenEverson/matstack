//! Instruction format and binary translation

pub const Command = enum(u8) {
    // Data processing
    nop,
    add,
    sub,
    /// element-wise multiplication
    /// broadcasts to enable scalar mul
    /// and vector-matrix element-wise mul
    mul,
    div,
    /// matrix multiplication
    matmul,
    transpose,
    relu,
    softmax,
    cross_entropy,
    dup,
    swap,
    exp,
    log,
    zeros_like,
    /// Sums along an axis provided in `extra`
    sum_reduce,

    // Memory
    load_const,
    /// Clones and loads the top tensor to
    /// a provided index into the scratch
    /// area
    load_i,
    /// Grabs and pushes the tensor at a provided
    /// index in the scratch area onto the stack
    store_i,
    drop,

    // Branching
    branch_always,
    branch_eq,
    branch_ne,

    // Debug
    debug_print,
};

cmd: Command = .nop,
extra: u8 = 0,
