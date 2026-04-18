//! Translation from AST to VM Bytecode!

pub const TranslationError = error{
    /// when a provided tensor literal is inconsistently sized, such as
    /// [[1,2,3], [1,2], [1,2,3]]
    MalformedTensor,
};
