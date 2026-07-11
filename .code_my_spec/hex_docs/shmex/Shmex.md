# Shmex



## empty/1

Creates a new, empty shared memory area with the given capacity

## new/1

Creates a new shared memory area filled with the existing data.

## new/2

Creates a new shared memory area initialized with `data` and sets its capacity.

The actual capacity is the greater of passed capacity and data size

## set_capacity/2

Sets the capacity of shared memory area.

If the capacity is smaller than the current size, data will be discarded and size modified

## ensure_not_gc/1

Ensures that shared memory is not garbage collected at the point of executing
this function.

Useful when passing shared memory to other OS process, to prevent it
from being garbage collected until received and mapped by that process.

## to_binary/1

Returns shared memory contents as a binary.