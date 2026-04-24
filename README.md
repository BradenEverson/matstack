# A Language, VM, and HDL Architecture for a Toy Tensor Processesing Machine

Yeah, that really says it all, more info in each subdirectory :)

This project is split up between the virtual machine runtime, actual hardware implementation, and the language that defines the bytecode for both. 

Using the `compile_and_run` shell script with a provided file will first compile to bytecode and then run that bytecode through the virtual machine. Using `compile_and_translate` will compile to bytecode, and then use that bytecode to derive IROM, Constant Pool, and Instruction constant VHDL files to be used in tandem with the rest of the computer architecture. 

The hardware implements a very small subset of the VM, because I am a better Zig writer than I am a VHDL architect. The goal is however to at the very least be able to fully train a neural network through the VM, then export those weights and run an inference on the FPGA. This source code for a small problem of solving squares can be found in `lang/sample/train`

So far, the most complex program to actually run on the FPGA is `lang/sample/forward`, it's a simple test program that runs one fully connected layer (Linear -> ReLu -> Linear) followed by MSE as well as accumulating the regularization loss from the 2 weight matrices W and M!
