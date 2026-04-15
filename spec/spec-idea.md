# MatStack program spec

A MatStack program consists of 
    1. A constant pool of all "immediate" values used
    2. A series of MatStack instructions that interact with the working stack

## General Structure

```
[[ 4 byte size header ]] -> N byte payload
[[ N bytes of Tensor descriptors ]]
[[ series 4-byte instructions until eof ]]
```

## Size Header
Not much to say here, just a 32-bit LE unsigned size of the constant pool size

## Constant Pool
From the size provided, the next `size` bytes belong to the constant pool. A constant in the constant pool is described as:

```
[ N dims ] [ dim 1  ] ... [ dim n  ] [ value 1  ] ... [ value (dim 1 * .. * dim n) ]
[ 4-byte ] [ 4-byte ] ... [ 4-byte ] [  4-byte  ] ... [          4-byte            ]
```

## Instructions
