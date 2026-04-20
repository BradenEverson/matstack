//! Instruction format and binary translation

pub const Command = enum(u8) {
    // Data processing
    nop,
    add,
    inc,
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
    pow,
    log,
    zeros_like,
    /// Sums along an axis provided in `extra`
    sum_reduce,
    /// just does a plain ol' sum
    sum,

    // Memory
    load_const,
    /// Pops and loads the top tensor to
    /// a provided index into the scratch
    /// area
    load_i,
    /// Like load, but doesn't pop the tensor off
    clone_i,
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
