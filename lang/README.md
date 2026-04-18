# High Level Tensor Language

This is pretty much just a python-like language that supports variables and applying tensor operations to those variables. It also supports control flow like looping. 

Keywords:

- `rand({shape})`
    - Constructs a random (at compile time) tensor with the provided shape
    - ex: `W = rand((2, 3))`

All the usual pytorch ops: *, +, -, @, plus some other stuff like softmax(), relu(), the works.

Sample Program:

```python
W = [[1,0],[0,1],[0,0]]
x = [[-10], [1]]

b = [[1],[2],[3]]

y = W @ x + b
debug(y)
```
