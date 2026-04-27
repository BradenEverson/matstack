//! Instruction format and binary translation

pub const Command = enum(u8) {
    // Data processing
    NOP,
    ADD,
    INC,
    SUB,
    /// element-wise multiplication
    /// broadcasts to enable scalar mul
    /// and vector-matrix element-wise mul
    MUL,
    DIV,
    /// matrix multiplication
    MATMUL,
    TRANSPOSE,
    RELU,
    SOFTMAX,
    CROSS_ENTROPY,
    DUP,
    SWAP,
    EXP,
    POW,
    LOG,

    /// Expects a vector-like to be popped with this format:
    /// [dim, start, end]. Where:
    /// - dim, must be a scalar
    /// - start: must be a scalar
    /// - end: must be a scalar
    SLICE,

    ZEROS_LIKE,

    // Element wise equality check (1 for true, 0 for false)
    EQ,
    // Element wise greater than (1 for true, 0 for false)
    GT,
    // Element wise less than (1 for true, 0 for false)
    LT,
    /// Sums along an axis provided in `extra`
    SUM_REDUCE,
    /// just does a plain ol' sum
    SUM,

    /// Computes the argmax index along an index
    ARGMAX,

    // Memory
    LOAD_CONST,
    /// Pops and loads the top tensor to
    /// a provided index into the scratch
    /// area
    LOAD_I,
    /// Like load, but doesn't pop the tensor off
    CLONE_I,
    /// Grabs and pushes the tensor at a provided
    /// index in the scratch area onto the stack
    STORE_I,
    DROP,

    // Branching
    BRANCH_ALWAYS,
    BRANCH_EQ,
    BRANCH_NE,

    // Save to file, file name is a single character in the extra
    SAVE,

    // Debug
    DEBUG_PRINT,
    HALT,
};

cmd: Command = .NOP,
extra: u8 = 0,
