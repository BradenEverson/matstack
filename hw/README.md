# The Actual Hardware Description Architecture!
This minimally implements a subset of the VM architecture to get some basic tensor operations up and running for now. The goal is to be able to train from the VM, export those weights and then run a forward inference off of the actual hardware, that would be really cool I think :)

It's implemented as a pipeline-style state machine that has the capability to "wait" during heavy operations such as matrix multiplication. The stack itself is also a clock-gated state machine, further requiring multiple cycles for pushing and popping.

All of this said, it is by no means an optimized or good architecture, the goal is to have fun and get it working for what I need. All while learning how to make my first stack-oriented computer architecture at the hardware level B)
