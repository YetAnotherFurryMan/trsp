#!/bin/bash

./clean.sh

mkdir build

zig12 build-exe -femit-bin=build/trsp src/main.zig

