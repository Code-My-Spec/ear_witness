# BiMultiMap

Bi-directional multimap implementation backed by two multimaps.

Entries in bimap do not follow any order.

BiMultiMaps do not impose any restriction on the key and value type: anything
can be a key in a bimap, and also anything can be a value.

BiMultiMaps differ from `BiMap`s by disallowing duplicates only among key-value
pairs, not among keys and values separately. This means it is possible to store
`[(A, B), (A, C)]` or `[(X, Z), (Y, Z)]` in BiMultiMap.

Keys and values are compared using the exact-equality operator (`===`).

## Example

    iex> mm = BiMultiMap.new(a: 1, b: 2, b: 1)
    BiMultiMap.new([a: 1, b: 1, b: 2])
    iex> BiMultiMap.get(mm, :a)
    [1]
    iex> BiMultiMap.get_keys(mm, 1)
    [:a, :b]
    iex> BiMultiMap.put(mm, :a, 3)
    BiMultiMap.new([a: 1, a: 3, b: 1, b: 2])

## Protocols

`BiMultiMap` implements `Enumerable`, `Collectable` and `Inspect` protocols.

## new/0

Creates a new bimultimap.

## Examples

    iex> BiMultiMap.new
    BiMultiMap.new([])

## new/1

Creates a bimultimap from `enumerable` of key-value pairs.

Duplicated pairs are removed; the latest one prevails.

## Examples

    iex> BiMultiMap.new([a: 1, a: 2])
    BiMultiMap.new([a: 1, a: 2])

## new/2

Creates a bimultimap from `enumerable` via transform function returning
key-value pairs.

## Examples

    iex> BiMultiMap.new([1, 2, 1], fn x -> {x, x * 2} end)
    BiMultiMap.new([{1, 2}, {2, 4}])

## size/1

Returns the number of elements in `bimultimap`.

The size of a bimultimap is the number of key-value pairs that the map
contains.

## Examples

    iex> BiMultiMap.size(BiMultiMap.new)
    0

    iex> bimultimap = BiMultiMap.new([a: "foo", a: "bar"])
    iex> BiMultiMap.size(bimultimap)
    2

## left/1

Returns `key ➜ [value]` mapping of `bimultimap`.

## Examples

    iex> bimultimap = BiMultiMap.new([a: "foo", b: "bar", b: "moo"])
    iex> BiMultiMap.left(bimultimap)
    %{a: ["foo"], b: ["bar", "moo"]}

## right/1

Returns `value ➜ key` mapping of `bimultimap`.

## Examples

    iex> bimultimap = BiMultiMap.new([a: "foo", b: "bar", c: "bar"])
    iex> BiMultiMap.right(bimultimap)
    %{"foo" => [:a], "bar" => [:b, :c]}

## keys/1

Returns all unique keys from `bimultimap`.

## Examples

    iex> bimultimap = BiMultiMap.new([a: 1, b: 2, b: 3])
    iex> BiMultiMap.keys(bimultimap)
    [:a, :b]

## values/1

Returns all unique values from `bimultimap`.

## Examples

    iex> bimultimap = BiMultiMap.new([a: 1, b: 2, c: 2])
    iex> BiMultiMap.values(bimultimap)
    [1, 2]

## member?/3

Checks if `bimultimap` contains `{key, value}` pair.

## Examples

    iex> bimultimap = BiMultiMap.new([a: "foo", a: "moo", b: "bar"])
    iex> BiMultiMap.member?(bimultimap, :a, "foo")
    true
    iex> BiMultiMap.member?(bimultimap, :a, "moo")
    true
    iex> BiMultiMap.member?(bimultimap, :a, "bar")
    false

## member?/2

Convenience shortcut for `member?/3`.

## has_key?/2

Checks if `bimultimap` contains `key`.

## Examples

    iex> bimultimap = BiMultiMap.new([a: "foo", b: "bar"])
    iex> BiMultiMap.has_key?(bimultimap, :a)
    true
    iex> BiMultiMap.has_key?(bimultimap, :x)
    false

## has_value?/2

Checks if `bimultimap` contains `value`.

## Examples

    iex> bimultimap = BiMultiMap.new([a: "foo", b: "bar"])
    iex> BiMultiMap.has_value?(bimultimap, "foo")
    true
    iex> BiMultiMap.has_value?(bimultimap, "moo")
    false

## equal?/2

Checks if two bimultimaps are equal.

Two bimultimaps are considered to be equal if they contain the same keys and
those keys are bound with the same values.

## Examples

    iex> Map.equal?(BiMultiMap.new([a: 1, b: 2, b: 3]), BiMultiMap.new([b: 2, b: 3, a: 1]))
    true
    iex> Map.equal?(BiMultiMap.new([a: 1, b: 2, b: 3]), BiMultiMap.new([b: 1, b: 3, a: 2]))
    false

## get/3

Gets all values for specific `key` in `bimultimap`

If `key` is present in `bimultimap` with values `values`, then `values` are
returned. Otherwise, `default` is returned (which is `[]` unless specified
otherwise).

## Examples

    iex> BiMultiMap.get(BiMultiMap.new(), :a)
    []
    iex> bimultimap = BiMultiMap.new([a: 1, c: 1, c: 2])
    iex> BiMultiMap.get(bimultimap, :a)
    [1]
    iex> BiMultiMap.get(bimultimap, :b)
    []
    iex> BiMultiMap.get(bimultimap, :b, 3)
    3
    iex> BiMultiMap.get(bimultimap, :c)
    [1, 2]

## get_keys/3

Gets all keys for specific `value` in `bimultimap`

This function is exact mirror of `get/3`.

## Examples

    iex> BiMultiMap.get_keys(BiMultiMap.new, 1)
    []
    iex> bimultimap = BiMultiMap.new([a: 1, c: 3, d: 3])
    iex> BiMultiMap.get_keys(bimultimap, 1)
    [:a]
    iex> BiMultiMap.get_keys(bimultimap, 2)
    []
    iex> BiMultiMap.get_keys(bimultimap, 2, :b)
    :b
    iex> BiMultiMap.get_keys(bimultimap, 3)
    [:c, :d]

## fetch/2

Fetches all values for specific `key` in `bimultimap`

If `key` is present in `bimultimap` with values `values`, then `{:ok, values}`
is returned. Otherwise, `:error` is returned.

## Examples

    iex> BiMultiMap.fetch(BiMultiMap.new(), :a)
    :error
    iex> bimultimap = BiMultiMap.new([a: 1, c: 1, c: 2])
    iex> BiMultiMap.fetch(bimultimap, :a)
    {:ok, [1]}
    iex> BiMultiMap.fetch(bimultimap, :b)
    :error
    iex> BiMultiMap.fetch(bimultimap, :c)
    {:ok, [1, 2]}

## fetch!/2

Fetches all values for specific `key` in `bimultimap`

Raises `ArgumentError` if the key is absent.

## Examples

    iex> bimultimap = BiMultiMap.new([a: 1, c: 1, c: 2])
    iex> BiMultiMap.fetch!(bimultimap, :a)
    [1]
    iex> BiMultiMap.fetch!(bimultimap, :c)
    [1, 2]

## fetch_keys/2

Fetches all keys for specific `value` in `bimultimap`

This function is exact mirror of `fetch/2`.

## Examples

    iex> BiMultiMap.fetch_keys(BiMultiMap.new, 1)
    :error
    iex> bimultimap = BiMultiMap.new([a: 1, c: 3, d: 3])
    iex> BiMultiMap.fetch_keys(bimultimap, 1)
    {:ok, [:a]}
    iex> BiMultiMap.fetch_keys(bimultimap, 2)
    :error
    iex> BiMultiMap.fetch_keys(bimultimap, 3)
    {:ok, [:c, :d]}

## fetch_keys!/2

Fetches all keys for specific `value` in `bimultimap`

Raises `ArgumentError` if the key is absent. This function is exact mirror of `fetch!/2`.

## Examples

    iex> bimultimap = BiMultiMap.new([a: 1, c: 3, d: 3])
    iex> BiMultiMap.fetch_keys!(bimultimap, 1)
    [:a]
    iex> BiMultiMap.fetch_keys!(bimultimap, 3)
    [:c, :d]

## put/3

Inserts `{key, value}` pair into `bimultimap`.

If `{key, value}` is already in `bimultimap`, it is deleted.

## Examples

    iex> bimultimap = BiMultiMap.new
    BiMultiMap.new([])
    iex> bimultimap = BiMultiMap.put(bimultimap, :a, 1)
    BiMultiMap.new([a: 1])
    iex> bimultimap = BiMultiMap.put(bimultimap, :a, 2)
    BiMultiMap.new([a: 1, a: 2])
    iex> BiMultiMap.put(bimultimap, :b, 2)
    BiMultiMap.new([a: 1, a: 2, b: 2])

## put/2

Convenience shortcut for `put/3`

## delete/3

Deletes `{key, value}` pair from `bimultimap`.

If the `key` does not exist, or `value` does not match, returns `bimultimap`
unchanged.

## Examples

    iex> bimultimap = BiMultiMap.new([a: 1, b: 2, c: 2])
    iex> BiMultiMap.delete(bimultimap, :b, 2)
    BiMultiMap.new([a: 1, c: 2])
    iex> BiMultiMap.delete(bimultimap, :c, 3)
    BiMultiMap.new([a: 1, b: 2, c: 2])

## delete_key/2

Deletes `{key, _}` pair from `bimultimap`.

If the `key` does not exist, returns `bimultimap` unchanged.

## Examples

    iex> bimultimap = BiMultiMap.new([a: 1, b: 2, b: 3])
    iex> BiMultiMap.delete_key(bimultimap, :b)
    BiMultiMap.new([a: 1])
    iex> BiMultiMap.delete_key(bimultimap, :c)
    BiMultiMap.new([a: 1, b: 2, b: 3])

## delete_value/2

Deletes `{_, value}` pair from `bimultimap`.

If the `value` does not exist, returns `bimultimap` unchanged.

## Examples

    iex> bimultimap = BiMultiMap.new([a: 1, b: 2, c: 1])
    iex> BiMultiMap.delete_value(bimultimap, 1)
    BiMultiMap.new([b: 2])
    iex> BiMultiMap.delete_value(bimultimap, 3)
    BiMultiMap.new([a: 1, b: 2, c: 1])

## delete/2

Convenience shortcut for `delete/3`.

## to_list/1

Returns list of unique key-value pairs in `bimultimap`.

## Examples

    iex> bimultimap = BiMultiMap.new([a: "foo", b: "bar"])
    iex> BiMultiMap.to_list(bimultimap)
    [a: "foo", b: "bar"]