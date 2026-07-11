# Ecto.UUID

An Ecto type for UUID strings.

## cast/1

Casts either a string in the canonical, human-readable UUID format or a
16-byte binary to a UUID in its canonical, human-readable UUID format.

If `uuid` is neither of these, `:error` will be returned.

Since both binaries and strings are represented as binaries, this means some
strings you may not expect are actually also valid UUIDs in their binary form
and so will be casted into their string form.

If you need further-restricted behavior or validation, you should define your
own custom `Ecto.Type`. There is also `Ecto.UUID.load/1` if you only want to
process `raw` UUIDs, which may be a more suitable reverse operation to
`Ecto.UUID.dump/1`.

## Examples

    iex> Ecto.UUID.cast(<<0x60, 0x1D, 0x74, 0xE4, 0xA8, 0xD3, 0x4B, 0x6E,
    ...>                  0x83, 0x65, 0xED, 0xDB, 0x4C, 0x89, 0x33, 0x27>>)
    {:ok, "601d74e4-a8d3-4b6e-8365-eddb4c893327"}

    iex> Ecto.UUID.cast("601d74e4-a8d3-4b6e-8365-eddb4c893327")
    {:ok, "601d74e4-a8d3-4b6e-8365-eddb4c893327"}

    iex> Ecto.UUID.cast("warehouse worker")
    {:ok, "77617265-686f-7573-6520-776f726b6572"}

## cast!/1

Same as `cast/1` but raises `Ecto.CastError` on invalid arguments.

## dump/1

Converts a string representing a UUID into a raw binary.

## dump!/1

Same as `dump/1` but raises `Ecto.ArgumentError` on invalid arguments.

## load/1

Converts a binary UUID into a string.

## load!/1

Same as `load/1` but raises `Ecto.ArgumentError` on invalid arguments.

## generate/0

Generates a random, version 4 UUID.

## bingenerate/0

Generates a random, version 4 UUID in the binary format.