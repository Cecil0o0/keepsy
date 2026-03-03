/// dense vector representation of semantic meaning
/// vector is an array of scalar numbers, typically floating-point numbers, while dense indicates high-dimensionality such as 768, 1024 and more.
/// In natural language processing and machine learning, a dense vector (also referred to as a word embedding) represents semantic meaning by mapping discrete linguistic units (such as words, sentences, or documents) into a continuous vector space.
/// I don't care how many dimensions the vector has, no matter sparse or dense, it always is a vector data struct, a floating number array in syntax-level, a continuous memory block in memory-level, a continuous disk block in disk-level.
/// I treat it as fixed arrays of floating point numbers, to be accessed and manipulated by index, for some computation such as Addition, Multiplication, Dot Product, Normalization, etc.
///
/// Summary:
/// - A vector is a contiguous `float[N]` buffer — nothing more, nothing less.
/// - All computations decompose into indexed loads → arithmetic → stores.
/// - Performance is governed by memory hierarchy, instruction-level parallelism, and data alignment—not by mathematical elegance.
const std = @import("std");

// even I think it is not necessary to use a struct to represent a vector, just a `[]f32` is enough.
// for algorithmic side, I deliver a vector as a `[]f32` to a function, and I expect the function to return a `[]f32` as the result.
// for computer side, I utilize the CPU for me to do the computation required by the algorithm.
// I play a role of an engineer to describe the algorithm to the computer, and I expect the computer to do what I want it to do.
const vec: []f32 = &[_]f32{ 0.1, 0.5, -0.3, 0.8, 0.0 };
