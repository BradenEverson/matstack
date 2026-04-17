# MatStack program spec

A MatStack program consists of 
    1. A constant pool of all "immediate" values used
    2. A series of MatStack instructions that interact with the working stack

## General Structure

```
[[ Header ]] 8-bytes
[[ Constant Pool ]] N-bytes
[[ Instructions ]] rest
```

## Size Header
Two 32-bit LE unsigned size of the constant pool, first in bytes and second in tensors

## Constant Pool
From the size provided, the next `size` bytes belong to the constant pool. A constant in the constant pool is described as:

```
[ N dims ] [ dim 1  ] ... [ dim n  ] [ value 1  ] ... [ value (dim 1 * .. * dim n) ]
[ 1-byte ] [ 4-byte ] ... [ 4-byte ] [  4-byte  ] ... [          4-byte            ]
```

## Instructions
An instruction occupies 2 bytes, with the first byte being the command and the second byte being any additional information necessary for the operation. For example, loading the 5th tensor from the constant pool onto the operand stack would be encoded as:

```
[         0x00       ] [      0x05      ]
[ LOAD_CONST command ] [ idx 5 in cpool ]
```
