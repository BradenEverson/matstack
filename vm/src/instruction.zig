//! Instruction format and binary translation

pub const Command = enum(u8) {
    // Data processing
    nop = 0x00,
    add = 0x01,
    sub = 0x02,
    /// element-wise multiplication
    /// broadcasts to enable scalar mul
    /// and vector-matrix element-wise mul
    mul = 0x03,
    /// matrix multiplication
    matmul = 0x04,
    transpose = 0x05,
    relu = 0x06,
    softmax = 0x07,
    cross_entropy = 0x08,
    dup = 0x09,
    swap = 0x0a,
    exp = 0x0b,
    log = 0x0c,
    /// Sums along an axis provided in `extra`
    sum_reduce = 0x0d,

    // Memory
    load_const = 0x0e,
    /// Clones and loads the top tensor to
    /// a provided index into the scratch
    /// area
    load_i = 0x0f,
    /// Grabs and pushes the tensor at a provided
    /// index in the scratch area onto the stack
    store_i = 0x10,
    drop = 0x11,

    // Branching
    branch_always = 0x12,
    branch_eq = 0x13,
    branch_ne = 0x14,

    // Debug
    debug_print = 0x15,

    div = 0x16,
};

cmd: Command = .nop,
extra: u8 = 0,
