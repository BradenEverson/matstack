#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <name>"
    exit 1
fi

NAME=$1

echo "Compiling..."

cd lang
zig build run -- sample/$NAME ../vm/sample/$NAME

echo "Translating..."

zig build translate -- ../vm/sample/$NAME
mv *.vhd ../hw
