#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <name>"
    exit 1
fi

NAME=$1

echo "Compiling..."

cd lang
zig build run -- sample/$NAME ../vm/sample/$NAME

echo "Running..."

cd ../vm
zig build run -Doptimize=ReleaseFast -- sample/$NAME
