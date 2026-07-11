# Nx.Defn.Composite

Functions to deal with composite data types.

Composite data-types are traversed according to `Nx.Container`.
If a regular tensor is given, it is individually traversed.
Numerical values, such as integers, floats, and complex numbers
are not normalized before hand. Use `Nx.to_tensor/1` to do so.

The functions in this module are invoked outside of `defn` or inside
`deftransform`. Note that, when a value is given to `defn`, it is
first converted to tensors and containers via `Nx.LazyContainer`.
Inside `defn`, there are no lazy containers, only containers.

## compatible?/3

Traverses two composite types to see if they are compatible.

Non-tensor values are first compared using `Nx.LazyContainer`
and then, if not available, as `Nx.Container`.

For non-composite types, the given `fun` will be called to
compare numbers/tensors pairwise.

## count/1

Counts the number of non-composite types in the composite type.

## Examples

    iex> Nx.Defn.Composite.count(123)
    1
    iex> Nx.Defn.Composite.count({1, {2, 3}})
    3
    iex> Nx.Defn.Composite.count({Complex.new(1), {Nx.tensor(2), 3}})
    3

## traverse/2

Traverses recursively the given composite types with `fun`.

If a composite tensor is given, such as a tuple, the composite
type is recursively traversed and returned.

Otherwise the function is invoked with the tensor (be it a
number, complex, or actual tensor).

## traverse/3

Traverses recursively the given composite types with `acc` and `fun`.

If a composite tensor is given, such as a tuple, the composite
type is recursively traversed and returned.

Otherwise the function is invoked with the tensor (be it a
number, complex, or actual tensor).

## reduce/3

Reduces recursively the given composite types with `acc` and `fun`.

If composite tensor expressions are given, such as a tuple,
the composite type is recursively traversed and returned.

If a non-composite tensor expression is given, the function
is invoked for it but not for its arguments.

## flatten_list/2

Flattens recursively the given list of composite types.

Elements that are not tensors (i.e. numbers and `Complex` numbers) are kept as is
unless a custom function is given.

## Examples

    iex> Nx.Defn.Composite.flatten_list([1, {2, 3}])
    [1, 2, 3]

    iex> Nx.Defn.Composite.flatten_list([1, {2, 3}], [Nx.tensor(4)])
    [1, 2, 3, Nx.tensor(4)]