# Bunch.Enum

A bunch of helper functions for manipulating enums.

## duplicates/2

Returns elements that occur at least `min_occurences` times in enumerable.

Results are NOT ordered in any sensible way, neither is the order anyhow preserved,
but it is deterministic.

## Examples

    iex> Bunch.Enum.duplicates([1,3,2,5,3,2,2])
    [2, 3]
    iex> Bunch.Enum.duplicates([1,3,2,5,3,2,2], 3)
    [2]