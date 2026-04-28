# A Directed Acyclic Computation Graph with Autograd
This exists as another frontend to the bytecode that can be run on the vm or hardware, with a specific focus on constructing a computation DAG that can be used for neural network construction and autograd training!

I like the idea of these graphs being able to "compile" down into modules that can be loaded by the script, that way more complex architectures can be described at a graph level, compiled down, then wired together into a training loop, that's probably what I'll end up doing :)
