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
    RELU_DER,
    SOFTMAX,
    CROSS_ENTROPY,
    DUP,
    SWAP,
    EXP,
    POW,
    LOG,
    ZEROS_LIKE,
    // Element wise greater than (1 for true, 0 for false)
    GT,
    // Element wise less than (1 for true, 0 for false)
    LT,
    /// Sums along an axis provided in `extra`
    SUM_REDUCE,
    /// just does a plain ol' sum
    SUM,

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

    // Debug
    DEBUG_PRINT,
};

cmd: Command = .NOP,
extra: u8 = 0,
