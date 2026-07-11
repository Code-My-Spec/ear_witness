# BiMap

Bi-directional map implementation backed by two maps.

> In computer science, a bidirectional map, or hash bag, is an associative data
> structure in which the `(key, value)` pairs form a one-to-one correspondence.
> Thus the binary relation is functional in each direction: `value` can also
> act as a key to `key`. A pair `(a, b)` thus provides a unique coupling
> between a `a` and `b` so that `b` can be found when `a` is used as a key and
> `a` can be found when `b` is used as a key.
>
> ~[Wikipedia](https://en.wikipedia.org/wiki/Bidirectional_map)

Entries in bimap do not follow any order.

BiMaps do not impose any restriction on the key and value type: anything can be
a key in a bimap, and also anything can be a value. As a bidirectional
key-value structure, bimaps do not allow duplicated keys and values. This means
it is not possible to store `[(A, B), (A, C)]` or `[(X, Z), (Y, Z)]` in
the bimap. If you need to lift this restriction to only not allowing duplicated
key-value pairs, check out `BiMultiMap`.

Keys and values are compared using the exact-equality operator (`===`).

## Example

    iex> bm = BiMap.new(a: 1, b: 2)
    BiMap.new([a: 1, b: 2])
    iex> BiMap.get(bm, :a)
    1
    iex> BiMap.get_key(bm, 2)
    :b
    iex> BiMap.put(bm, :a, 3)
    BiMap.new([a: 3, b: 2])
    iex> BiMap.put(bm, :c, 2)
    BiMap.new([a: 1, c: 2])

## Protocols

`BiMap` implements `Enumerable`, `Collectable` and `Inspect` protocols.

## new/0

Creates a new bimap.

## Examples

    iex> BiMap.new
    BiMap.new([])

## new/1

Creates a bimap from `enumerable` of key-value pairs.

Duplicated pairs are removed; the latest one prevails.

## Examples

    iex> BiMap.new([a: "foo", b: "bar"])
    BiMap.new([a: "foo", b: "bar"])

## new/2

Creates a bimap from `enumerable` via transform function returning key-value
pairs.

## Examples

    iex> BiMap.new([1, 2, 1], fn x -> {x, x * 2} end)
    BiMap.new([{1, 2}, {2, 4}])

## size/1

Returns the number of elements in `bimap`.

The size of a bimap is the number of key-value pairs that the map contains.

## Examples

    iex> BiMap.size(BiMap.new)
    0

    iex> bimap = BiMap.new([a: "foo", b: "bar"])
    iex> BiMap.size(bimap)
    2

## left/1

Returns `key ➜ value` mapping of `bimap`.

## Examples

    iex> bimap = BiMap.new([a: "foo", b: "bar"])
    iex> BiMap.left(bimap)
    %{a: "foo", b: "bar"}

## right/1

Returns `value ➜ key` mapping of `bimap`.

## Examples

    iex> bimap = BiMap.new([a: "foo", b: "bar"])
    iex> BiMap.right(bimap)
    %{"foo" => :a, "bar" => :b}

## keys/1

Returns all keys from `bimap`.

## Examples

    iex> bimap = BiMap.new([a: 1, b: 2])
    iex> BiMap.keys(bimap)
    [:a, :b]

## values/1

Returns all values from `bimap`.

## Examples

    iex> bimap = BiMap.new([a: 1, b: 2])
    iex> BiMap.values(bimap)
    [1, 2]

## member?/3

Checks if `bimap` contains `{key, value}` pair.

## Examples

    iex> bimap = BiMap.new([a: "foo", b: "bar"])
    iex> BiMap.member?(bimap, :a, "foo")
    true
    iex> BiMap.member?(bimap, :a, "bar")
    false

## member?/2

Convenience shortcut for `member?/3`.

## has_key?/2

Checks if `bimap` contains `key`.

## Examples

    iex> bimap = BiMap.new([a: "foo", b: "bar"])
    iex> BiMap.has_key?(bimap, :a)
    true
    iex> BiMap.has_key?(bimap, :x)
    false

## has_value?/2

Checks if `bimap` contains `value`.

## Examples

    iex> bimap = BiMap.new([a: "foo", b: "bar"])
    iex> BiMap.has_value?(bimap, "foo")
    true
    iex> BiMap.has_value?(bimap, "moo")
    false

## equal?/2

Checks if two bimaps are equal.

Two bimaps are considered to be equal if they contain the same keys and those
keys contain the same values.

## Examples

    iex> Map.equal?(BiMap.new([a: 1, b: 2]), BiMap.new([b: 2, a: 1]))
    true
    iex> Map.equal?(BiMap.new([a: 1, b: 2]), BiMap.new([b: 1, a: 2]))
    false

## get/3

Gets the value for specific `key` in `bimap`

If `key` is present in `bimap` with value `value`, then `value` is returned.
Otherwise, `default` is returned (which is `nil` unless specified otherwise).

## Examples

    iex> BiMap.get(BiMap.new(), :a)
    nil
    iex> bimap = BiMap.new([a: 1])
    iex> BiMap.get(bimap, :a)
    1
    iex> BiMap.get(bimap, :b)
    nil
    iex> BiMap.get(bimap, :b, 3)
    3

## get_key/3

Gets the key for specific `value` in `bimap`

This function is exact mirror of `get/3`.

## Examples

    iex> BiMap.get_key(BiMap.new, 1)
    nil
    iex> bimap = BiMap.new([a: 1])
    iex> BiMap.get_key(bimap, 1)
    :a
    iex> BiMap.get_key(bimap, 2)
    nil
    iex> BiMap.get_key(bimap, 2, :b)
    :b

## fetch/2

Fetches the value for specific `key` in `bimap`

If `key` is present in `bimap` with value `value`, then `{:ok, value}` is
returned. Otherwise, `:error` is returned.

## Examples

    iex> BiMap.fetch(BiMap.new(), :a)
    :error
    iex> bimap = BiMap.new([a: 1])
    iex> BiMap.fetch(bimap, :a)
    {:ok, 1}
    iex> BiMap.fetch(bimap, :b)
    :error

## fetch!/2

Fetches the value for specific `key` in `bimap`.

Raises `ArgumentError` if the key is absent.

## Examples

    iex> bimap = BiMap.new([a: 1])
    iex> BiMap.fetch!(bimap, :a)
    1

## fetch_key/2

Fetches the key for specific `value` in `bimap`

This function is exact mirror of `fetch/2`.

## Examples

    iex> BiMap.fetch_key(BiMap.new, 1)
    :error
    iex> bimap = BiMap.new([a: 1])
    iex> BiMap.fetch_key(bimap, 1)
    {:ok, :a}
    iex> BiMap.fetch_key(bimap, 2)
    :error

## fetch_key!/2

Fetches the key for specific `value` in `bimap`.

Raises `ArgumentError` if the value is absent. This function is exact mirror of `fetch!/2`.

## Examples

    iex> bimap = BiMap.new([a: 1])
    iex> BiMap.fetch_key!(bimap, 1)
    :a

## put/3

Inserts `{key, value}` pair into `bimap`.

If either `key` or `value` is already in `bimap`, any overlapping bindings are
deleted.

## Examples

    iex> bimap = BiMap.new
    BiMap.new([])
    iex> bimap = BiMap.put(bimap, :a, 0)
    BiMap.new([a: 0])
    iex> bimap = BiMap.put(bimap, :a, 1)
    BiMap.new([a: 1])
    iex> BiMap.put(bimap, :b, 1)
    BiMap.new([b: 1])

## put/2

Convenience shortcut for `put/3`

## put_new_key/3

Inserts `{key, value}` pair into `bimap` if `key` is not already in `bimap`.

If `key` already exists in `bimap`, `bimap` is returned unchanged.

If `key` does not exist and `value` is already in `bimap`, any overlapping bindings are
deleted.

## Examples

    iex> bimap = BiMap.new
    BiMap.new([])
    iex> bimap = BiMap.put_new_key(bimap, :a, 0)
    BiMap.new([a: 0])
    iex> bimap = BiMap.put_new_key(bimap, :a, 1)
    BiMap.new([a: 0])
    iex> BiMap.put_new_key(bimap, :b, 1)
    BiMap.new([a: 0, b: 1])
    iex> BiMap.put_new_key(bimap, :c, 1)
    BiMap.new([a: 0, c: 1])

## put_new_value/3

Inserts `{key, value}` pair into `bimap` if `value` is not already in `bimap`.

If `value` already exists in `bimap`, `bimap` is returned unchanged.

If `value` does not exist and `key` is already in `bimap`, any overlapping bindings are
deleted.

## Examples

    iex> bimap = BiMap.new
    BiMap.new([])
    iex> bimap = BiMap.put_new_value(bimap, :a, 0)
    BiMap.new([a: 0])
    iex> bimap = BiMap.put_new_value(bimap, :a, 1)
    BiMap.new([a: 1])
    iex> BiMap.put_new_value(bimap, :b, 1)
    BiMap.new([a: 1])
    iex> BiMap.put_new_value(bimap, :c, 2)
    BiMap.new([a: 1, c: 2])

## delete/3

Deletes `{key, value}` pair from `bimap`.

If the `key` does not exist, or `value` does not match, returns `bimap`
unchanged.

## Examples

    iex> bimap = BiMap.new([a: 1, b: 2])
    iex> BiMap.delete(bimap, :b, 2)
    BiMap.new([a: 1])
    iex> BiMap.delete(bimap, :c, 3)
    BiMap.new([a: 1, b: 2])
    iex> BiMap.delete(bimap, :b, 3)
    BiMap.new([a: 1, b: 2])

## delete_key/2

Deletes `{key, _}` pair from `bimap`.

If the `key` does not exist, returns `bimap` unchanged.

## Examples

    iex> bimap = BiMap.new([a: 1, b: 2])
    iex> BiMap.delete_key(bimap, :b)
    BiMap.new([a: 1])
    iex> BiMap.delete_key(bimap, :c)
    BiMap.new([a: 1, b: 2])

## delete_value/2

Deletes `{_, value}` pair from `bimap`.

If the `value` does not exist, returns `bimap` unchanged.

## Examples

    iex> bimap = BiMap.new([a: 1, b: 2])
    iex> BiMap.delete_value(bimap, 2)
    BiMap.new([a: 1])
    iex> BiMap.delete_value(bimap, 3)
    BiMap.new([a: 1, b: 2])

## delete/2

Convenience shortcut for `delete/3`.

## to_list/1

Returns list of unique key-value pairs in `bimap`.

## Examples

    iex> bimap = BiMap.new([a: "foo", b: "bar"])
    iex> BiMap.to_list(bimap)
    [a: "foo", b: "bar"]