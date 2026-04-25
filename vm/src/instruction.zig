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

    // Extra is
    // [ start ] [ bound ]
    // [ 1-bit ] [ 7-bit ]
    //
    // Start bit represents if this is a starting or ending bound
    // Ex: [1:] would be a starting bound, [:5] ending, [1:3]
    // would be two subsequent commands as a start and end
    //
    // These are also placed in the enum like they are such that
    // you can interpret the lower 2-bits of the opcode as the
    // dimension the slice is operating on!
    // These are the "fixed" slices, runtime slicing uses stack ops for this
    SLICE0 = 0x10,
    SLICE1 = 0x11,
    SLICE2 = 0x12,
    SLICE3 = 0x13,

    /// "Runtime" version of the slice
    /// Operands are popped in this order:
    /// - dim, must be a scalar
    /// - start: must be a scalar
    /// - end: must be a scalar
    SLICE,

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
    HALT,
};

cmd: Command = .NOP,
extra: u8 = 0,
