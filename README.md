# A Language, VM, and HDL Architecture for a Toy Tensor Processesing Machine

Yeah, that really says it all, more info in each subdirectory :)

This project is split up between the virtual machine runtime, actual hardware implementation, and the language that defines the bytecode for both. 

Using the `compile_and_run` shell script with a provided file will first compile to bytecode and then run that bytecode through the virtual machine. Using `compile_and_translate` will compile to bytecode, and then use that bytecode to derive IROM, Constant Pool, and Instruction constant VHDL files to be used in tandem with the rest of the computer architecture. 

The hardware implements a very small subset of the VM, because I am a better Zig writer than I am a VHDL architect. The goal is however to at the very least be able to fully train a neural network through the VM, then export those weights and run an inference on the FPGA. This source code for a small problem of solving squares can be found in `lang/sample/train`

So far, the most complex program to actually run on the FPGA is `lang/sample/forward`, it's a simple test program that runs one fully connected layer (Linear -> ReLu -> Linear) followed by MSE as well as accumulating the regularization loss from the 2 weight matrices W and M!


Test Forward Pass:

```python
epsilon = 0.01

x = [[-10], [1]]
y = [[10], [5]]

W = [[1, 0], [0, 1], [0, 0]]
M = [[0, -1, 2], [1, 3, -5]]
b = [[1], [2], [3]]
c = [[-10], [10]]

u = W @ x + b
h = relu(u)

v = M @ h + c
L = sum((y - v)^2) / 2

S1 = epsilon * sum(W^2)
S2 = epsilon * sum(M^2)

S = S1 + S2
J = L + S

debug(J)
```



VM Result:
<img width="1285" height="85" alt="image" src="https://github.com/user-attachments/assets/1edce902-f761-4e6f-8223-5b11f50b7069" />



HDL Result (Seven Seg shows upper 6 nibbles of the float):
<img width="800" height="600" alt="image" src="https://github.com/user-attachments/assets/363c5a8b-b44e-4f01-8796-b4f2f2a5c01b" />


(0x4311_6B85 = 145.42, simulation waveforms show this as the result and we'll just have to trust that the FPGA truly got the lower byte right too)
