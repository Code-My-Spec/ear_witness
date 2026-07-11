# Shmex.Native

This module provides natively implemented functions allowing low-level
operations on Posix shared memory. Use with caution!

## read/1

Reads the contents of shared memory and returns it as a binary.

## trim/1

Trims shared memory capacity to match its size.

## trim/2

Drops `bytes` bytes from the beginning of shared memory area and
trims it to match the new size.