# High Level Tensor Language

This is pretty much just a python-like language that supports variables and applying tensor operations to those variables. It also supports control flow like looping. 

Keywords:

- `tensor({raw_tensor})`
    - Constructs a tensor from a multidimensional array
    - ex: `W = tensor([[1,2,3],[0.5,6,0]])`

- `rand({shape})`
    - Constructs a random (at compile time) tensor with the provided shape
    - ex: `W = rand((2, 3))`

All the usual pytorch ops: *, +, -, @, plus some other stuff like softmax(), relu(), the works.
