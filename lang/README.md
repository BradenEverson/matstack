# High Level Tensor Language

This is pretty much just a python-like language that supports variables and applying tensor operations to those variables. It also supports control flow like looping. 

Features:

- Tensor definition like you would with a multi-dim array
- random initialization from provided shapes (compile time randomness so the architecture doesn't need a random number generator)
- All the usual pytorch ops: *, +, -, @, plus some other stuff like softmax(), relu(), the works.

Sample Program:

```python
W = [[1,0],[0,1],[0,0]]
x = [[-10], [1]]

b = [[1],[2],[3]]

y = W @ x + b
debug(y)
```

## Compiler General Algorithm
When we create the AST from this small language, traversing it creates intuitive translation rules into the VM bytecode. For example:

- When a variable assignment expression is reached, we first evaluate the result instructions by performing their operations, then we can use a load_i with the next available scratch area slot to store that variable, and keep this index in a hashmap. Next time this variable is referenced, we evaluate it by performing a store_i and putting it back on the stack!

- When a binary expression is reached, lhs is evaluated and all necessary instructions are appended, then all of rhs's instructions are appended before then appending the instruction itself!

I'm mostly writing this here for myself later
