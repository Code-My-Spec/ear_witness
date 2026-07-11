# Poison



## encode/2

Encode a value to JSON.

    iex> Poison.encode([1, 2, 3])
    {:ok, "[1,2,3]"}

## encode_to_iodata/2

Encode a value to JSON as iodata.

    iex> Poison.encode_to_iodata([1, 2, 3])
    {:ok, [91, ["1", 44, "2", 44, "3"], 93]}

## encode!/2

Encode a value to JSON, raises an exception on error.

    iex> Poison.encode!([1, 2, 3])
    "[1,2,3]"

## encode_to_iodata!/2

Encode a value to JSON as iodata, raises an exception on error.

    iex> Poison.encode_to_iodata!([1, 2, 3])
    [91, ["1", 44, "2", 44, "3"], 93]

## decode/2

Decode JSON to a value.

    iex> Poison.decode("[1,2,3]")
    {:ok, [1, 2, 3]}

## decode!/2

Decode JSON to a value, raises an exception on error.

    iex> Poison.decode!("[1,2,3]")
    [1, 2, 3]