//! Tensors are the core value of matstack, so we should probably design 'em pretty well

const std = @import("std");

pub const Tensor = struct {
    /// An UNOWNED look into the data
    /// the VM truly owns this in an arena
    /// like structure
    data: []const f32,

    /// The shape in row-first order
    shape: []usize,

    /// Offset for slices into existing tensors
    offset: usize = 0,

    /// for each dimension along the shape,
    /// how many elements we move forward
    /// flatly to get to the next index.
    /// ex: in a 2x3 matrix, strides would
    /// be [3, 1] to move down a row or col
    strides: []usize,
};
