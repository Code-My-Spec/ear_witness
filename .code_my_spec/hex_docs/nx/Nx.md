# Nx

Numerical Elixir.

The `Nx` library is a collection of functions and data
types to work with Numerical Elixir. This module defines
the main entry point for building and working with said
data-structures. For example, to create an n-dimensional
tensor, do:

    iex> t = Nx.tensor([[1, 2], [3, 4]])
    iex> Nx.shape(t)
    {2, 2}

`Nx` also provides the so-called numerical definitions under
the `Nx.Defn` module. They are a subset of Elixir tailored for
numerical computations. For example, it overrides Elixir's
default operators so they are tensor-aware:

    defn softmax(t) do
      Nx.exp(t) / Nx.sum(Nx.exp(t))
    end

Code inside `defn` functions can also be given to custom compilers,
which can compile said functions just-in-time (JIT) to run on the
CPU or on the GPU.

## References

Here is a general outline of the main references in this library:

  * For an introduction, see our [Intro to Nx](introduction.md) guide

  * This module provides the main API for working with tensors

  * `Nx.Defn` provides numerical definitions, CPU/GPU compilation, gradients, and more

  * `Nx.LinAlg` provides functions related to linear algebra

  * `Nx.Constants` declares many constants commonly used in numerical code

Continue reading this documentation for an overview of creating,
broadcasting, and accessing/slicing Nx tensors.

## Creating tensors

The main APIs for creating tensors are `tensor/2`, `from_binary/2`,
`iota/2`, `eye/2`, and `broadcast/3`.

The tensor types can be one of:

  * unsigned integers (`u2`, `u4`, `u8`, `u16`, `u32`, `u64`)
  * signed integers (`s2`, `s4`, `s8`, `s16`, `s32`, `s64`)
  * floats (`f16`, `f32`, `f64`)
  * brain floats (`bf16`)
  * quantized floats (`f8` (E5M2), `f8_e4m3fn`)
  * and complex numbers (`c64`, `c128`)

The types are tracked as tuples:

    iex> Nx.tensor([1, 2, 3], type: {:f, 32})
    #Nx.Tensor<
      f32[3]
      [1.0, 2.0, 3.0]
    >

But a shortcut atom notation is also available:

    iex> Nx.tensor([1, 2, 3], type: :f32)
    #Nx.Tensor<
      f32[3]
      [1.0, 2.0, 3.0]
    >

The tensor dimensions can also be named, via the `:names` option
available to all creation functions:

    iex> Nx.iota({2, 3}, names: [:x, :y])
    #Nx.Tensor<
      s32[x: 2][y: 3]
      [
        [0, 1, 2],
        [3, 4, 5]
      ]
    >

Finally, for creating vectors and matrices, a sigil notation
is available:

    iex> import Nx, only: :sigils
    iex> ~VEC[1 2 3]f32
    #Nx.Tensor<
      f32[3]
      [1.0, 2.0, 3.0]
    >

    iex> import Nx, only: :sigils
    iex> ~MAT'''
    ...> 1 2 3
    ...> 4 5 6
    ...> '''s32
    #Nx.Tensor<
      s32[2][3]
      [
        [1, 2, 3],
        [4, 5, 6]
      ]
    >

All other APIs accept exclusively numbers or tensors, unless
explicitly noted otherwise.

## Broadcasting

Broadcasting allows operations on two tensors of different shapes
to match. For example, most often operations between tensors have
the same shape:

    iex> a = Nx.tensor([1, 2, 3])
    iex> b = Nx.tensor([10, 20, 30])
    iex> Nx.add(a, b)
    #Nx.Tensor<
      s32[3]
      [11, 22, 33]
    >

Now let's imagine you want to multiply a large tensor of dimensions
1000x1000x1000 by 2. If you had to create a similarly large tensor
only to perform this operation, it would be inefficient. Therefore,
you can simply multiply this large tensor by the scalar 2, and Nx
will propagate its dimensions at the time the operation happens,
without allocating a large intermediate tensor:

    iex> Nx.multiply(Nx.tensor([1, 2, 3]), 2)
    #Nx.Tensor<
      s32[3]
      [2, 4, 6]
    >

In practice, broadcasting is not restricted only to scalars; it
is a general algorithm that applies to all dimensions of a tensor.
When broadcasting, `Nx` compares the shapes of the two tensors,
starting with the trailing ones, such that:

  * If the dimensions have equal size, then they are compatible

  * If one of the dimensions have size of 1, it is "broadcast"
    to match the dimension of the other

In case one tensor has more dimensions than the other, the missing
dimensions are considered to be of size one. Here are some examples
of how broadcast would work when multiplying two tensors with the
following shapes:

    s32[3] * s64
    #=> s32[3]

    s32[255][255][3] * s32[3]
    #=> s32[255][255][3]

    s32[2][1] * s[1][2]
    #=> s32[2][2]

    s32[5][1][4][1] * s32[3][4][5]
    #=> s32[5][3][4][5]

If any of the dimensions do not match or are not 1, an error is
raised.

## Access syntax (slicing)

Nx tensors implement Elixir's access syntax. This allows developers
to slice tensors up and easily access sub-dimensions and values.

Access accepts integers:

    iex> t = Nx.tensor([[1, 2], [3, 4]])
    iex> t[0]
    #Nx.Tensor<
      s32[2]
      [1, 2]
    >
    iex> t[1]
    #Nx.Tensor<
      s32[2]
      [3, 4]
    >
    iex> t[1][1]
    #Nx.Tensor<
      s32
      4
    >

If a negative index is given, it accesses the element from the back:

    iex> t = Nx.tensor([[1, 2], [3, 4]])
    iex> t[-1][-1]
    #Nx.Tensor<
      s32
      4
    >

Out of bound access will raise:

    iex> Nx.tensor([1, 2])[2]
    ** (ArgumentError) index 2 is out of bounds for axis 0 in shape {2}

    iex> Nx.tensor([1, 2])[-3]
    ** (ArgumentError) index -3 is out of bounds for axis 0 in shape {2}

The index can also be another tensor. If the tensor is a scalar, it must
be a value between 0 and the dimension size, and it behaves the same as
an integer. Out of bound dynamic indexes are always clamped to the tensor
dimensions:

    iex> two = Nx.tensor(2)
    iex> t = Nx.tensor([[1, 2], [3, 4]])
    iex> t[two][two]
    #Nx.Tensor<
      s32
      4
    >

For example, a `minus_one` dynamic index will be clamped to zero:

    iex> minus_one = Nx.tensor(-1)
    iex> t = Nx.tensor([[1, 2], [3, 4]])
    iex> t[minus_one][minus_one]
    #Nx.Tensor<
      s32
      1
    >

A multi-dimensional tensor uses its values to fetch the leading
dimension of the tensor, placing them within the shape of the
indexing tensor. It is equivalent to `take/3`:

    iex> t = Nx.tensor([[1, 2], [3, 4]])
    iex> t[Nx.tensor([1, 0])]
    #Nx.Tensor<
      s32[2][2]
      [
        [3, 4],
        [1, 2]
      ]
    >

The example shows how the retrieved indexes are nested
with the accessed shape and that you may also access
repeated indices:

    iex> t = Nx.tensor([[1, 2], [3, 4]])
    iex> t[Nx.tensor([[1, 0, 1]])]
    #Nx.Tensor<
      s32[1][3][2]
      [
        [
          [3, 4],
          [1, 2],
          [3, 4]
        ]
      ]
    >

Access also accepts ranges. Ranges in Elixir are inclusive:

    iex> t = Nx.tensor([[1, 2], [3, 4], [5, 6], [7, 8]])
    iex> t[0..1]
    #Nx.Tensor<
      s32[2][2]
      [
        [1, 2],
        [3, 4]
      ]
    >

Ranges can receive negative positions and they will read from
the back. In such cases, the range step must be explicitly given
and the right-side of the range must be equal or greater than
the left-side:

    iex> t = Nx.tensor([[1, 2], [3, 4], [5, 6], [7, 8]])
    iex> t[1..-2//1]
    #Nx.Tensor<
      s32[2][2]
      [
        [3, 4],
        [5, 6]
      ]
    >

As you can see, accessing with a range does not eliminate the
accessed axis. This means that, if you try to cascade ranges,
you will always be filtering the highest dimension:

    iex> t = Nx.tensor([[1, 2], [3, 4], [5, 6], [7, 8]])
    iex> t[1..-1//1] # Drop the first "row"
    #Nx.Tensor<
      s32[3][2]
      [
        [3, 4],
        [5, 6],
        [7, 8]
      ]
    >
    iex> t[1..-1//1][1..-1//1] # Drop the first "row" twice
    #Nx.Tensor<
      s32[2][2]
      [
        [5, 6],
        [7, 8]
      ]
    >

Therefore, if you want to slice across multiple dimensions, you can wrap
the ranges in a list:

    iex> t = Nx.tensor([[1, 2], [3, 4], [5, 6], [7, 8]])
    iex> t[[1..-1//1, 1..-1//1]] # Drop the first "row" and the first "column"
    #Nx.Tensor<
      s32[3][1]
      [
        [4],
        [6],
        [8]
      ]
    >

You can also use `..` as the full-slice range, which means you want to
keep a given dimension as is:

    iex> t = Nx.tensor([[1, 2], [3, 4], [5, 6], [7, 8]])
    iex> t[[.., 1..-1//1]] # Drop only the first "column"
    #Nx.Tensor<
      s32[4][1]
      [
        [2],
        [4],
        [6],
        [8]
      ]
    >

You can mix both ranges and integers in the list too:

    iex> t = Nx.tensor([[1, 2, 3], [4, 5, 6], [7, 8, 9], [10, 11, 12]])
    iex> t[[1..2, 2]]
    #Nx.Tensor<
      s32[2]
      [6, 9]
    >

If the list has less elements than axes, the remaining dimensions
are returned in full:

    iex> t = Nx.tensor([[1, 2, 3], [4, 5, 6], [7, 8, 9], [10, 11, 12]])
    iex> t[[1..2]]
    #Nx.Tensor<
      s32[2][3]
      [
        [4, 5, 6],
        [7, 8, 9]
      ]
    >

The access syntax also pairs nicely with named tensors. By using named
tensors, you can pass only the axis you want to slice, leaving the other
axes intact:

    iex> t = Nx.tensor([[1, 2, 3], [4, 5, 6], [7, 8, 9], [10, 11, 12]], names: [:x, :y])
    iex> t[x: 1..2]
    #Nx.Tensor<
      s32[x: 2][y: 3]
      [
        [4, 5, 6],
        [7, 8, 9]
      ]
    >
    iex> t[x: 1..2, y: 0..1]
    #Nx.Tensor<
      s32[x: 2][y: 2]
      [
        [4, 5],
        [7, 8]
      ]
    >
    iex> t[x: 1, y: 0..1]
    #Nx.Tensor<
      s32[y: 2]
      [4, 5]
    >

For a more complex slicing rules, including strides, you
can always fallback to `Nx.slice/4`.

## Backends

The `Nx` library has built-in support for multiple backends.
A tensor is always handled by a backend, the default backend
being `Nx.BinaryBackend`, which means the tensor is allocated
as a binary within the Erlang VM.

Most often backends are used to provide a completely different
implementation of tensor operations, often accelerated to the GPU.
In such cases, you want to guarantee all tensors are allocated in
the new backend. This can be done by configuring your runtime:

    # config/runtime.exs
    import Config
    config :nx, default_backend: EXLA.Backend

In your notebooks and on `Mix.install/2`, you might:

    Mix.install(
      [
        {:nx, ">= 0.0.0"}
      ],
      config: [nx: [default_backend: EXLA.Backend]]
    )

Or by calling `Nx.global_default_backend/1` (less preferable):

    Nx.global_default_backend(EXLA.Backend)

To pass options to the backend, replacing `EXLA.Backend` by
`{EXLA.Backend, client: :cuda}` or similar. See the documentation
for [EXLA](https://hexdocs.pm/exla) and [Torchx](https://hexdocs.pm/torchx)
for installation and GPU support.

To implement your own backend, check the `Nx.Tensor` behaviour.

## tensor/2

Builds a tensor.

The argument must be one of:

  * a tensor
  * a number (which means the tensor is scalar/zero-dimensional)
  * a boolean (also scalar/zero-dimensional)
  * an arbitrarily nested list of numbers and booleans

If a new tensor has to be allocated, it will be allocated in
`Nx.default_backend/0`, unless the `:backend` option is given,
which overrides the default one.

## Examples

A number returns a tensor of zero dimensions:

    iex> Nx.tensor(0)
    #Nx.Tensor<
      s32
      0
    >

    iex> Nx.tensor(1.0)
    #Nx.Tensor<
      f32
      1.0
    >

Giving a list returns a vector (a one-dimensional tensor):

    iex> Nx.tensor([1, 2, 3])
    #Nx.Tensor<
      s32[3]
      [1, 2, 3]
    >

    iex> Nx.tensor([1.2, 2.3, 3.4, 4.5])
    #Nx.Tensor<
      f32[4]
      [1.2, 2.3, 3.4, 4.5]
    >

The type can be explicitly given. Integers and floats
bigger than the given size overflow:

    iex> Nx.tensor([300, 301, 302], type: :s8)
    #Nx.Tensor<
      s8[3]
      [44, 45, 46]
    >

Mixed types give higher priority to floats:

    iex> Nx.tensor([1, 2, 3.0])
    #Nx.Tensor<
      f32[3]
      [1.0, 2.0, 3.0]
    >

Boolean values are also accepted, where `true` is
converted to `1` and `false` to `0`, with the type
being inferred as `{:u, 8}`

    iex> Nx.tensor(true)
    #Nx.Tensor<
      u8
      1
    >

    iex> Nx.tensor(false)
    #Nx.Tensor<
      u8
      0
    >

    iex> Nx.tensor([true, false])
    #Nx.Tensor<
      u8[2]
      [1, 0]
    >

Multi-dimensional tensors are also possible:

    iex> Nx.tensor([[1, 2, 3], [4, 5, 6]])
    #Nx.Tensor<
      s32[2][3]
      [
        [1, 2, 3],
        [4, 5, 6]
      ]
    >

    iex> Nx.tensor([[1, 2], [3, 4], [5, 6]])
    #Nx.Tensor<
      s32[3][2]
      [
        [1, 2],
        [3, 4],
        [5, 6]
      ]
    >

    iex> Nx.tensor([[[1, 2], [3, 4], [5, 6]], [[-1, -2], [-3, -4], [-5, -6]]])
    #Nx.Tensor<
      s32[2][3][2]
      [
        [
          [1, 2],
          [3, 4],
          [5, 6]
        ],
        [
          [-1, -2],
          [-3, -4],
          [-5, -6]
        ]
      ]
    >

## Floats and complex numbers

Besides single-precision (32 bits), floats can also have
half-precision (16) or double-precision (64):

    iex> Nx.tensor([1, 2, 3], type: :f16)
    #Nx.Tensor<
      f16[3]
      [1.0, 2.0, 3.0]
    >

    iex> Nx.tensor([1, 2, 3], type: :f64)
    #Nx.Tensor<
      f64[3]
      [1.0, 2.0, 3.0]
    >

Brain-floating points are also supported:

    iex> Nx.tensor([1, 2, 3], type: :bf16)
    #Nx.Tensor<
      bf16[3]
      [1.0, 2.0, 3.0]
    >

We also supported two types of quantized floats (see next section).

In all cases, the non-finite values negative infinity (-Inf),
infinity (Inf), and "not a number" (NaN) can be represented by
the atoms `:neg_infinity`, `:infinity`, and `:nan` respectively:

    iex> Nx.tensor([:neg_infinity, :nan, :infinity])
    #Nx.Tensor<
      f32[3]
      [-Inf, NaN, Inf]
    >

Finally, complex numbers are also supported in tensors:

    iex> Nx.tensor(Complex.new(1, -1))
    #Nx.Tensor<
      c64
      1.0-1.0i
    >

## Quantized floats

Certain backends and compilers support 8-bit floats. Two types
of 8-bit floats are currently supported: `f8` and `f8_e4m3fn`.

The `f8` type is effectively (E5M2) and works similarly to
the other floating numbers, as specified by IEEE:

    iex> Nx.tensor([1, 2, 3], type: :f8)
    #Nx.Tensor<
      f8[3]
      [1.0, 2.0, 3.0]
    >

The `f8_e4m3fn` type, however, does not support infinites
(`fn` stands for finite and NaNs).

    iex> Nx.tensor([1, 2, 3], type: :f8_e4m3fn)
    #Nx.Tensor<
      f8_e4m3fn[3]
      [1.0, 2.0, 3.0]
    >

Once a value is out of range, it saturates either at the maximum
or minimum supported value:

    iex> Nx.tensor([:infinity], type: :f8_e4m3fn)
    #Nx.Tensor<
      f8_e4m3fn[1]
      [450.0]
    >

## Naming dimensions

You can provide names for tensor dimensions. Names are atoms:

    iex> Nx.tensor([[1, 2, 3], [4, 5, 6]], names: [:x, :y])
    #Nx.Tensor<
      s32[x: 2][y: 3]
      [
        [1, 2, 3],
        [4, 5, 6]
      ]
    >

Names make your code more expressive:

    iex> Nx.tensor([[[1, 2, 3], [4, 5, 6], [7, 8, 9]]], names: [:batch, :height, :width])
    #Nx.Tensor<
      s32[batch: 1][height: 3][width: 3]
      [
        [
          [1, 2, 3],
          [4, 5, 6],
          [7, 8, 9]
        ]
      ]
    >

You can also leave dimension names as `nil`:

    iex> Nx.tensor([[[1, 2, 3], [4, 5, 6], [7, 8, 9]]], names: [:batch, nil, nil])
    #Nx.Tensor<
      s32[batch: 1][3][3]
      [
        [
          [1, 2, 3],
          [4, 5, 6],
          [7, 8, 9]
        ]
      ]
    >

However, you must provide a name for every dimension in the tensor:

    iex> Nx.tensor([[[1, 2, 3], [4, 5, 6], [7, 8, 9]]], names: [:batch])
    ** (ArgumentError) invalid names for tensor of rank 3, when specifying names every dimension must have a name or be nil

## Tensors

Tensors can also be given as inputs:

    iex> Nx.tensor(Nx.tensor([1, 2, 3]))
    #Nx.Tensor<
      s32[3]
      [1, 2, 3]
    >

If the `:backend` and `:type` options are given, the tensor will
compared against those values and raise in case of mismatch:

    iex> Nx.tensor(Nx.tensor([1, 2, 3]), type: :f32)
    ** (ArgumentError) Nx.tensor/2 expects a tensor with type :f32 but it was given a tensor of type {:s, 32}

The `:backend` option will check only against the backend name
and not specific backend configuration such as device and client.
In case the backend differs, it will also raise.

The names in the given tensor are always discarded but Nx will raise
in case the tensor already has names that conflict with the assigned ones:

    iex> Nx.tensor(Nx.tensor([1, 2, 3]), names: [:row])
    #Nx.Tensor<
      s32[row: 3]
      [1, 2, 3]
    >

    iex> Nx.tensor(Nx.tensor([1, 2, 3], names: [:column]))
    #Nx.Tensor<
      s32[3]
      [1, 2, 3]
    >

    iex> Nx.tensor(Nx.tensor([1, 2, 3], names: [:column]), names: [:row])
    ** (ArgumentError)  cannot merge name :column on axis 0 with name :row on axis 0

## Options

  * `:type` - sets the type of the tensor. If one is not given,
    one is automatically inferred based on the input.

  * `:names` - dimension names. If you wish to specify dimension
    names you must specify a name for every dimension in the tensor.
    Only `nil` and atoms are supported as dimension names.

  * `:backend` - the backend to allocate the tensor on. It is either
    an atom or a tuple in the shape `{backend, options}`. It defaults
    to `Nx.default_backend/0` for new tensors

## template/3

Creates a tensor template.

You can't perform any operation on this tensor.
It exists exclusively to define APIs that say
a tensor with a certain type, shape, and names
is expected in the future.

## Examples

    iex> Nx.template({2, 3}, :f32)
    #Nx.Tensor<
      f32[2][3]
      Nx.TemplateBackend
    >

    iex> Nx.template({2, 3}, {:f, 32}, names: [:rows, :columns])
    #Nx.Tensor<
      f32[rows: 2][columns: 3]
      Nx.TemplateBackend
    >

Although note it is impossible to perform any operation on a tensor template:

    iex> t = Nx.template({2, 3}, {:f, 32}, names: [:rows, :columns])
    iex> Nx.abs(t)
    ** (RuntimeError) cannot perform operations on a Nx.TemplateBackend tensor

To convert existing tensors to templates, use `to_template/1`.

## to_template/1

Converts a tensor (or tuples and maps of tensors) to tensor templates.

Templates are useful when you need to pass types and shapes to
operations and the data is not yet available.

For convenience, this function accepts tensors and any container
(such as maps and tuples as defined by the `Nx.LazyContainer` protocol)
and recursively converts all tensors to templates.

## Examples

    iex> Nx.iota({2, 3}) |> Nx.to_template()
    #Nx.Tensor<
      s32[2][3]
      Nx.TemplateBackend
    >

    iex> {int, float} = Nx.to_template({1, 2.0})
    iex> int
    #Nx.Tensor<
      s32
      Nx.TemplateBackend
    >
    iex> float
    #Nx.Tensor<
      f32
      Nx.TemplateBackend
    >

Although note it is impossible to perform any operation on a tensor template:

    iex> t = Nx.iota({2, 3}) |> Nx.to_template()
    iex> Nx.abs(t)
    ** (RuntimeError) cannot perform operations on a Nx.TemplateBackend tensor

To build a template from scratch, use `template/3`.

## iota/2

Creates a tensor with the given shape which increments
along the provided axis. You may optionally provide dimension
names.

If no axis is provided, index counts up at each element.

If a tensor or a number are given, the shape and names are taken from the tensor.

## Options

  * `:type` - the type of the tensor

  * `:axis` - an axis to repeat the iota over

  * `:names` - the names of the tensor dimensions

  * `:backend` - the backend to allocate the tensor on. It is either
    an atom or a tuple in the shape `{backend, options}`. This option
    is ignored inside `defn`

  * `:vectorized_axes` - a keyword list of `axis_name: axis_size`.
    If given, the resulting tensor will be vectorized accordingly.
    Vectorization is not supported via tensor inputs.

## Examples

    iex> Nx.iota({})
    #Nx.Tensor<
      s32
      0
    >

    iex> Nx.iota({5})
    #Nx.Tensor<
      s32[5]
      [0, 1, 2, 3, 4]
    >

    iex> Nx.iota({3, 2, 3}, names: [:batch, :height, :width])
    #Nx.Tensor<
      s32[batch: 3][height: 2][width: 3]
      [
        [
          [0, 1, 2],
          [3, 4, 5]
        ],
        [
          [6, 7, 8],
          [9, 10, 11]
        ],
        [
          [12, 13, 14],
          [15, 16, 17]
        ]
      ]
    >

    iex> Nx.iota({3, 3}, axis: 1, names: [:batch, nil])
    #Nx.Tensor<
      s32[batch: 3][3]
      [
        [0, 1, 2],
        [0, 1, 2],
        [0, 1, 2]
      ]
    >

    iex> Nx.iota({3, 3}, axis: -1)
    #Nx.Tensor<
      s32[3][3]
      [
        [0, 1, 2],
        [0, 1, 2],
        [0, 1, 2]
      ]
    >

    iex> Nx.iota({3, 4, 3}, axis: 0, type: :f64)
    #Nx.Tensor<
      f64[3][4][3]
      [
        [
          [0.0, 0.0, 0.0],
          [0.0, 0.0, 0.0],
          [0.0, 0.0, 0.0],
          [0.0, 0.0, 0.0]
        ],
        [
          [1.0, 1.0, 1.0],
          [1.0, 1.0, 1.0],
          [1.0, 1.0, 1.0],
          [1.0, 1.0, 1.0]
        ],
        [
          [2.0, 2.0, 2.0],
          [2.0, 2.0, 2.0],
          [2.0, 2.0, 2.0],
          [2.0, 2.0, 2.0]
        ]
      ]
    >

    iex> Nx.iota({1, 3, 2}, axis: 2)
    #Nx.Tensor<
      s32[1][3][2]
      [
        [
          [0, 1],
          [0, 1],
          [0, 1]
        ]
      ]
    >

    iex> Nx.iota({2, 3}, axis: 0, vectorized_axes: [x: 1, y: 2])
    #Nx.Tensor<
      vectorized[x: 1][y: 2]
      s32[2][3]
      [
        [
          [
            [0, 0, 0],
            [1, 1, 1]
          ],
          [
            [0, 0, 0],
            [1, 1, 1]
          ]
        ]
      ]
    >

## eye/2

Creates the identity matrix of size `n`.

## Options

  * `:type` - the type of the tensor

  * `:names` - the names of the tensor dimensions

  * `:backend` - the backend to allocate the tensor on. It is either
    an atom or a tuple in the shape `{backend, options}`. This option
    is ignored inside `defn`

  * `:vectorized_axes` - a keyword list of `axis_name: axis_size`.
    If given, the resulting tensor will be vectorized accordingly.
    Vectorization is not supported via tensor inputs.

## Examples

    iex> Nx.eye(2)
    #Nx.Tensor<
      s32[2][2]
      [
        [1, 0],
        [0, 1]
      ]
    >

    iex> Nx.eye(3, type: :f32, names: [:height, :width])
    #Nx.Tensor<
      f32[height: 3][width: 3]
      [
        [1.0, 0.0, 0.0],
        [0.0, 1.0, 0.0],
        [0.0, 0.0, 1.0]
      ]
    >

The first argument can also be a shape of a matrix:

    iex> Nx.eye({1, 2})
    #Nx.Tensor<
      s32[1][2]
      [
        [1, 0]
      ]
    >

The shape can also represent a tensor batch. In this case,
the last two axes will represent the same identity matrix.

    iex> Nx.eye({2, 4, 3})
    #Nx.Tensor<
      s32[2][4][3]
      [
        [
          [1, 0, 0],
          [0, 1, 0],
          [0, 0, 1],
          [0, 0, 0]
        ],
        [
          [1, 0, 0],
          [0, 1, 0],
          [0, 0, 1],
          [0, 0, 0]
        ]
      ]
    >

## Vectorized tensors

If given, vectorized axes, are added as leading dimensions to the tensor,
effectively broadcasting the base shape along them.

    iex> Nx.eye({3}, vectorized_axes: [x: 1, y: 2])
    #Nx.Tensor<
      vectorized[x: 1][y: 2]
      s32[3]
      [
        [
          [1, 0, 0],
          [1, 0, 0]
        ]
      ]
    >

    iex> Nx.eye({2, 3}, vectorized_axes: [x: 2])
    #Nx.Tensor<
      vectorized[x: 2]
      s32[2][3]
      [
        [
          [1, 0, 0],
          [0, 1, 0]
        ],
        [
          [1, 0, 0],
          [0, 1, 0]
        ]
      ]
    >

## tril/2

Lower triangle of a matrix.

## Options

  * `k` - The diagonal above which to zero elements. Default: 0.

## Examples

    iex> Nx.tril(Nx.tensor([[1, 2, 3], [4, 5, 6], [7, 8, 9]]))
    #Nx.Tensor<
      s32[3][3]
      [
        [1, 0, 0],
        [4, 5, 0],
        [7, 8, 9]
      ]
    >

    iex> Nx.tril(Nx.tensor([[1, 2, 3], [4, 5, 6], [7, 8, 9]]), k: 1)
    #Nx.Tensor<
      s32[3][3]
      [
        [1, 2, 0],
        [4, 5, 6],
        [7, 8, 9]
      ]
    >

    iex> Nx.tril(Nx.iota({2, 3, 4}))
    #Nx.Tensor<
      s32[2][3][4]
      [
        [
          [0, 0, 0, 0],
          [4, 5, 0, 0],
          [8, 9, 10, 0]
        ],
        [
          [12, 0, 0, 0],
          [16, 17, 0, 0],
          [20, 21, 22, 0]
        ]
      ]
    >

    iex> Nx.tril(Nx.iota({6}))
    ** (ArgumentError) tril/2 expects a tensor with at least 2 dimensions, got: #Nx.Tensor<
      s32[6]
      [0, 1, 2, 3, 4, 5]
    >

## triu/2

Upper triangle of an array.

## Options

  * `k` - The diagonal below which to zero elements. Default: 0.

## Examples

    iex> Nx.triu(Nx.tensor([[1, 2, 3], [4, 5, 6], [7, 8, 9]]))
    #Nx.Tensor<
      s32[3][3]
      [
        [1, 2, 3],
        [0, 5, 6],
        [0, 0, 9]
      ]
    >

    iex> Nx.triu(Nx.tensor([[1, 2, 3], [4, 5, 6], [7, 8, 9]]), k: 1)
    #Nx.Tensor<
      s32[3][3]
      [
        [0, 2, 3],
        [0, 0, 6],
        [0, 0, 0]
      ]
    >

    iex> Nx.triu(Nx.iota({2, 3, 4}))
    #Nx.Tensor<
      s32[2][3][4]
      [
        [
          [0, 1, 2, 3],
          [0, 5, 6, 7],
          [0, 0, 10, 11]
        ],
        [
          [12, 13, 14, 15],
          [0, 17, 18, 19],
          [0, 0, 22, 23]
        ]
      ]
    >

    iex> Nx.triu(Nx.iota({6}))
    ** (ArgumentError) triu/2 expects a tensor with at least 2 dimensions, got: #Nx.Tensor<
      s32[6]
      [0, 1, 2, 3, 4, 5]
    >

## tri/3

An array with ones at and below the given diagonal and zeros elsewhere.

## Options

  * `k` - The diagonal above which to zero elements. Default: 0.

## Examples

    iex> tensor = Nx.tensor([[1, 2, 3], [4, 5, 6], [7, 8, 9]])
    iex> {num_rows, num_cols} = Nx.shape(tensor)
    iex> Nx.tri(num_rows, num_cols)
    #Nx.Tensor<
      u8[3][3]
      [
        [1, 0, 0],
        [1, 1, 0],
        [1, 1, 1]
      ]
    >

    iex> tensor = Nx.tensor([[1, 2, 3], [4, 5, 6], [7, 8, 9]])
    iex> {num_rows, num_cols} = Nx.shape(tensor)
    iex> Nx.tri(num_rows, num_cols, k: 1)
    #Nx.Tensor<
      u8[3][3]
      [
        [1, 1, 0],
        [1, 1, 1],
        [1, 1, 1]
      ]
    >

## take_diagonal/2

Extracts the diagonal of batched matrices.

Converse of `make_diagonal/2`.

## Examples

Given a matrix without offset:

    iex> Nx.take_diagonal(Nx.tensor([
    ...> [0, 1, 2],
    ...> [3, 4, 5],
    ...> [6, 7, 8]
    ...> ]))
    #Nx.Tensor<
      s32[3]
      [0, 4, 8]
    >

And if given a matrix along with an offset:

    iex> Nx.take_diagonal(Nx.iota({3, 3}), offset: 1)
    #Nx.Tensor<
      s32[2]
      [1, 5]
    >

    iex> Nx.take_diagonal(Nx.iota({3, 3}), offset: -1)
    #Nx.Tensor<
      s32[2]
      [3, 7]
    >

Given batched matrix:

    iex> Nx.take_diagonal(Nx.iota({3, 2, 2}))
    #Nx.Tensor<
      s32[3][2]
      [
        [0, 3],
        [4, 7],
        [8, 11]
      ]
    >

    iex> Nx.take_diagonal(Nx.iota({3, 2, 2}), offset: -1)
    #Nx.Tensor<
      s32[3][1]
      [
        [2],
        [6],
        [10]
      ]
    >

## Options

  * `:offset` - offset used for extracting the diagonal.
    Use offset > 0 for diagonals above the main diagonal,
    and offset < 0 for diagonals below the main diagonal.
    Defaults to 0.

## Error cases

    iex> Nx.take_diagonal(Nx.tensor([0, 1, 2]))
    ** (ArgumentError) take_diagonal/2 expects tensor of rank 2 or higher, got tensor of rank: 1

    iex> Nx.take_diagonal(Nx.iota({3, 3}), offset: 3)
    ** (ArgumentError) offset must be less than length of axis 1 when positive, got: 3

    iex> Nx.take_diagonal(Nx.iota({3, 3}), offset: -4)
    ** (ArgumentError) absolute value of offset must be less than length of axis 0 when negative, got: -4

## make_diagonal/2

Creates a diagonal tensor from a 1D tensor.

Converse of `take_diagonal/2`.

The returned tensor will be a square matrix of dimensions equal
to the size of the tensor. If an offset is given, the absolute value
of the offset is added to the matrix dimensions sizes.

## Options

  * `:offset` - offset used for making the diagonal.
    Use offset > 0 for diagonals above the main diagonal,
    and offset < 0 for diagonals below the main diagonal.
    Defaults to 0.

## Examples

  Given a 1D tensor:

    iex> Nx.make_diagonal(Nx.tensor([1, 2, 3, 4]))
    #Nx.Tensor<
      s32[4][4]
      [
        [1, 0, 0, 0],
        [0, 2, 0, 0],
        [0, 0, 3, 0],
        [0, 0, 0, 4]
      ]
    >

  Given a 1D tensor with an offset:

    iex> Nx.make_diagonal(Nx.tensor([1, 2, 3]), offset: 1)
    #Nx.Tensor<
      s32[4][4]
      [
        [0, 1, 0, 0],
        [0, 0, 2, 0],
        [0, 0, 0, 3],
        [0, 0, 0, 0]
      ]
    >

    iex> Nx.make_diagonal(Nx.tensor([1, 2, 3]), offset: -1)
    #Nx.Tensor<
      s32[4][4]
      [
        [0, 0, 0, 0],
        [1, 0, 0, 0],
        [0, 2, 0, 0],
        [0, 0, 3, 0]
      ]
    >

  You can also have offsets with an abs greater than the tensor length:

    iex> Nx.make_diagonal(Nx.tensor([1, 2, 3]), offset: -4)
    #Nx.Tensor<
      s32[7][7]
      [
        [0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0],
        [1, 0, 0, 0, 0, 0, 0],
        [0, 2, 0, 0, 0, 0, 0],
        [0, 0, 3, 0, 0, 0, 0]
      ]
    >

    iex> Nx.make_diagonal(Nx.tensor([1, 2, 3]), offset: 4)
    #Nx.Tensor<
      s32[7][7]
      [
        [0, 0, 0, 0, 1, 0, 0],
        [0, 0, 0, 0, 0, 2, 0],
        [0, 0, 0, 0, 0, 0, 3],
        [0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0]
      ]
    >

### Vectorized tensors

    iex> t = Nx.vectorize(Nx.tensor([[1, 2], [3, 4]]), :x)
    iex> Nx.make_diagonal(t, offset: 1)
    #Nx.Tensor<
      vectorized[x: 2]
      s32[3][3]
      [
        [
          [0, 1, 0],
          [0, 0, 2],
          [0, 0, 0]
        ],
        [
          [0, 3, 0],
          [0, 0, 4],
          [0, 0, 0]
        ]
      ]
    >
    iex> Nx.make_diagonal(t, offset: -1)
    #Nx.Tensor<
      vectorized[x: 2]
      s32[3][3]
      [
        [
          [0, 0, 0],
          [1, 0, 0],
          [0, 2, 0]
        ],
        [
          [0, 0, 0],
          [3, 0, 0],
          [0, 4, 0]
        ]
      ]
    >

## Error cases

    iex> Nx.make_diagonal(Nx.tensor([[0, 0], [0, 1]]))
    ** (ArgumentError) make_diagonal/2 expects tensor of rank 1, got tensor of rank: 2

## put_diagonal/3

Puts the individual values from a 1D diagonal into the diagonal indices
of the given 2D tensor.

See also: `take_diagonal/2`, `make_diagonal/2`.

## Examples

Given a 2D tensor and a 1D diagonal:

    iex> t = Nx.broadcast(0, {4, 4})
    #Nx.Tensor<
      s32[4][4]
      [
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0]
      ]
    >
    iex> Nx.put_diagonal(t, Nx.tensor([1, 2, 3, 4]))
    #Nx.Tensor<
      s32[4][4]
      [
        [1, 0, 0, 0],
        [0, 2, 0, 0],
        [0, 0, 3, 0],
        [0, 0, 0, 4]
      ]
    >

    iex> t = Nx.broadcast(0, {4, 3})
    #Nx.Tensor<
      s32[4][3]
      [
        [0, 0, 0],
        [0, 0, 0],
        [0, 0, 0],
        [0, 0, 0]
      ]
    >
    iex> Nx.put_diagonal(t, Nx.tensor([1, 2, 3]))
    #Nx.Tensor<
      s32[4][3]
      [
        [1, 0, 0],
        [0, 2, 0],
        [0, 0, 3],
        [0, 0, 0]
      ]
    >

Given a 2D tensor and a 1D diagonal with a positive offset:

    iex> Nx.put_diagonal(Nx.broadcast(0, {4, 4}), Nx.tensor([1, 2, 3]), offset: 1)
    #Nx.Tensor<
      s32[4][4]
      [
        [0, 1, 0, 0],
        [0, 0, 2, 0],
        [0, 0, 0, 3],
        [0, 0, 0, 0]
      ]
    >

    iex> Nx.put_diagonal(Nx.broadcast(0, {4, 3}), Nx.tensor([1, 2]), offset: 1)
    #Nx.Tensor<
      s32[4][3]
      [
        [0, 1, 0],
        [0, 0, 2],
        [0, 0, 0],
        [0, 0, 0]
      ]
    >

Given a 2D tensor and a 1D diagonal with a negative offset:

    iex> Nx.put_diagonal(Nx.broadcast(0, {4, 4}), Nx.tensor([1, 2, 3]), offset: -1)
    #Nx.Tensor<
      s32[4][4]
      [
        [0, 0, 0, 0],
        [1, 0, 0, 0],
        [0, 2, 0, 0],
        [0, 0, 3, 0]
      ]
    >

    iex> Nx.put_diagonal(Nx.broadcast(0, {4, 3}), Nx.tensor([1, 2, 3]), offset: -1)
    #Nx.Tensor<
      s32[4][3]
      [
        [0, 0, 0],
        [1, 0, 0],
        [0, 2, 0],
        [0, 0, 3]
      ]
    >

## Options

  * `:offset` - offset used for putting the diagonal.
    Use offset > 0 for diagonals above the main diagonal,
    and offset < 0 for diagonals below the main diagonal.
    Defaults to 0.


## Error cases

Given an invalid tensor:

    iex> Nx.put_diagonal(Nx.iota({3, 3, 3}), Nx.iota({3}))
    ** (ArgumentError) put_diagonal/3 expects tensor of rank 2, got tensor of rank: 3

Given invalid diagonals:

    iex> Nx.put_diagonal(Nx.iota({3, 3}), Nx.iota({3, 3}))
    ** (ArgumentError) put_diagonal/3 expects diagonal of rank 1, got tensor of rank: 2

    iex> Nx.put_diagonal(Nx.iota({3, 3}), Nx.iota({2}))
    ** (ArgumentError) expected diagonal tensor of length: 3, got diagonal tensor of length: 2

    iex> Nx.put_diagonal(Nx.iota({3, 3}), Nx.iota({3}), offset: 1)
    ** (ArgumentError) expected diagonal tensor of length: 2, got diagonal tensor of length: 3

Given invalid offsets:

    iex> Nx.put_diagonal(Nx.iota({3, 3}), Nx.iota({3}), offset: 4)
    ** (ArgumentError) offset must be less than length of axis 1 when positive, got: 4

    iex> Nx.put_diagonal(Nx.iota({3, 3}), Nx.iota({3}), offset: -3)
    ** (ArgumentError) absolute value of offset must be less than length of axis 0 when negative, got: -3

## from_binary/3

Creates a one-dimensional tensor from a `binary` with the given `type`.

If the binary size does not match its type, an error is raised.

## Examples

    iex> Nx.from_binary(<<1, 2, 3, 4>>, :s8)
    #Nx.Tensor<
      s8[4]
      [1, 2, 3, 4]
    >

The atom notation for types is also supported:

    iex> Nx.from_binary(<<12.3::float-64-native>>, :f64)
    #Nx.Tensor<
      f64[1]
      [12.3]
    >

An error is raised for incompatible sizes:

    iex> Nx.from_binary(<<1, 2, 3, 4>>, :f64)
    ** (ArgumentError) binary does not match the given size

## Options

  * `:backend` - the backend to allocate the tensor on. It is either
    an atom or a tuple in the shape `{backend, options}`. This option
    is ignored inside `defn`

## to_binary/2

Returns the underlying tensor as a binary.

It returns the in-memory binary representation of
the tensor in a row-major fashion. The binary is
in the system endianness, which has to be taken into
account if the binary is meant to be serialized to
other systems.

This function cannot be used in `defn`.

> ### Potentially expensive operation {: .warning}
>
> Converting a tensor to a binary can potentially be a very
> expensive operation, as it may copy a GPU tensor fully to
> the machine memory.

> ### Binaries vs bitstrings {: .info}
>
> If a tensor of type u2/u4/s2/s4 is given to this function,
> this function may not return a binary (where the number of bits
> is divisible by 8) but rather a bitstring (where the number of
> bits may not be divisible by 8).

## Options

  * `:limit` - limit the number of entries represented in the binary

## Examples

    iex> Nx.to_binary(1)
    <<1::32-native>>

    iex> Nx.to_binary(Nx.tensor([1.0, 2.0, 3.0]))
    <<1.0::float-32-native, 2.0::float-32-native, 3.0::float-32-native>>

    iex> Nx.to_binary(Nx.tensor([1.0, 2.0, 3.0]), limit: 2)
    <<1.0::float-32-native, 2.0::float-32-native>>

### Vectorized tensors

`to_binary/2` disregards the vectorized axes before calculating the data to be returned:

    iex> Nx.to_binary(Nx.vectorize(Nx.tensor([[1, 2], [3, 4]]), :x))
    <<1::32-native, 2::32-native, 3::32-native, 4::32-native>>

    iex> Nx.to_binary(Nx.vectorize(Nx.tensor([1, 2, 3]), :x), limit: 2)
    <<1::32-native, 2::32-native>>

## to_tensor/1

Converts a data structure into a tensor.

This function only converts types which are automatically
cast to tensors throughout Nx API: numbers, complex numbers,
tensors themselves, and implementations of `Nx.LazyContainer`
(and `Nx.Container`).

If your goal is to create tensors from lists, see `tensor/2`.
If you want to create a tensor from binary, see `from_binary/3`.
If you want to convert a data structure with several tensors at
once into a single one, see `stack/2` or `concatenate/2` instead.

## to_flat_list/2

Returns the underlying tensor as a flat list.

Negative infinity (-Inf), infinity (Inf), and "not a number" (NaN)
will be represented by the atoms `:neg_infinity`, `:infinity`, and
`:nan` respectively.

Note: This function cannot be used in `defn`.

## Examples

    iex> Nx.to_flat_list(1)
    [1]

    iex> Nx.to_flat_list(Nx.tensor([1.0, 2.0, 3.0]))
    [1.0, 2.0, 3.0]

    iex> Nx.to_flat_list(Nx.tensor([1.0, 2.0, 3.0]), limit: 2)
    [1.0, 2.0]

Non-finite numbers are returned as atoms:

    iex> t = Nx.tensor([:neg_infinity, :nan, :infinity])
    iex> Nx.to_flat_list(t)
    [:neg_infinity, :nan, :infinity]

### Vectorized tensors

`to_flat_list/2` disregards the vectorized axes before calculating the data to be returned.
Like `to_binary/1`, `:limit` refers to the flattened devectorized data.

    iex> t = Nx.vectorize(Nx.tensor([[1], [2], [3], [4]]), :x)
    iex> Nx.to_flat_list(t)
    [1, 2, 3, 4]
    iex> Nx.to_flat_list(t, limit: 2)
    [1, 2]

## to_list/1

Converts the tensor into a list reflecting its structure.

Negative infinity (-Inf), infinity (Inf), and "not a number" (NaN)
will be represented by the atoms `:neg_infinity`, `:infinity`, and
`:nan` respectively.

It raises if a scalar tensor is given, use `to_number/1` instead.

Note: This function cannot be used in `defn`.

## Examples

    iex> Nx.iota({2, 3}) |> Nx.to_list()
    [
      [0, 1, 2],
      [3, 4, 5]
    ]

    iex> Nx.tensor(123) |> Nx.to_list()
    ** (ArgumentError) cannot convert a scalar tensor to a list, got: #Nx.Tensor<
      s32
      123
    >

### Vectorized tensors

`to_list/1` disregards the vectorized axes before calculating the data to be returned.
The special case below shows that a vectorized tensor with inner scalar shape will
still be converted to a list accordingly:

    iex> %{shape: {}} = t = Nx.vectorize(Nx.tensor([1, 2, 3]), :x)
    iex> Nx.to_list(t) # recall that normally, shape == {} would raise!
    [1, 2, 3]

## runtime_call/4

Invokes an Elixir function from within `defn`.

This function allows integrating arbitrary Elixir code into `defn` graphs.
It receives an output template (a tensor or a tuple of tensors) that
specifies the expected shapes, types, and names of the result, a tensor
or tensor container argument and the function itself.

Tensors passed to the callback function are in the same backend as the inputs in the case
of `Nx.Defn.Evaluator` invocations. For other compilers, it is generally expected that
the tensors will be provided as `Nx.BinaryBackend` tensors.

> #### Device locks {: .warning}
>
> `runtime_call/4` will generally operate on tensors allocated on a given physical device, such as a GPU.
> For example, EXLA will have one or more CPU clients.
>
> When calling other Nx computations from within the callback, these other computations cannot operate
> on the same device as this will result in a deadlock.

> #### Backend transfers {: .warning}
>
> When executing a `runtime_call/4` in `Nx.Defn.Evaluator`, the tensors should not be transferred with `Nx.backend_transfer/2`,
> because the values passed might still be used in the rest of the computation. If needed, you can use `Nx.backend_copy/2` to another backend instead.

## Examples

While most code inside `defn` is restricted, `runtime_call/4` allows you
to perform arbitrary Elixir operations, such as message passing.
The callback must be a named capture (e.g. `&my_callback/2`):

    iex> defmodule RuntimeCallExample do
    ...>   def callback(t, opts) do
    ...>     send(opts[:pid], {:sum, Enum.sum(Nx.to_flat_list(t))})
    ...>     t
    ...>   end
    ...> end
    iex> pid = self()
    iex> x = Nx.tensor([1, 2, 3])
    iex> out = Nx.template({3}, {:s, 32})
    iex> Nx.runtime_call(out, x, [pid: pid], &RuntimeCallExample.callback/2)
    #Nx.Tensor<
      s32[3]
      [1, 2, 3]
    >
    iex> receive do {:sum, value} -> value end
    6

Inside `defn`, this builds an expression node that is supported by compilers.
Outside of `defn` or in backends without special support, it executes `fun`
directly and validates that the result matches the provided template.

## to_batched/3

Converts the underlying tensor to a stream of tensor batches.

The first dimension (axis 0) is divided by `batch_size`.
In case the dimension cannot be evenly divided by
`batch_size`, you may specify what to do with leftover
data using `:leftover`. `:leftover` must be one of `:repeat`
or `:discard`. `:repeat` repeats the first `n` values to
make the last batch match the desired batch size. `:discard`
discards excess elements.

Note: This function cannot be used in `defn`.

## Examples

In the examples below we immediately pipe to `Enum.to_list/1`
for convenience, but in practice you want to lazily traverse
the batches to avoid allocating multiple tensors at once in
certain backends:

    iex> [first, second] = Nx.to_batched(Nx.iota({2, 2, 2}), 1) |> Enum.to_list()
    iex> first
    #Nx.Tensor<
      s32[1][2][2]
      [
        [
          [0, 1],
          [2, 3]
        ]
      ]
    >
    iex> second
    #Nx.Tensor<
      s32[1][2][2]
      [
        [
          [4, 5],
          [6, 7]
        ]
      ]
    >

If the batch size would result in uneven batches, you can repeat or discard excess data.
By default, we repeat:

    iex> [first, second, third] = Nx.to_batched(Nx.iota({5, 2}, names: [:x, :y]), 2) |> Enum.to_list()
    iex> first
    #Nx.Tensor<
      s32[x: 2][y: 2]
      [
        [0, 1],
        [2, 3]
      ]
    >
    iex> second
    #Nx.Tensor<
      s32[x: 2][y: 2]
      [
        [4, 5],
        [6, 7]
      ]
    >
    iex> third
    #Nx.Tensor<
      s32[x: 2][y: 2]
      [
        [8, 9],
        [0, 1]
      ]
    >

But you can also discard:

    iex> [first, second] = Nx.to_batched(Nx.iota({5, 2}, names: [:x, :y]), 2, leftover: :discard) |> Enum.to_list()
    iex> first
    #Nx.Tensor<
      s32[x: 2][y: 2]
      [
        [0, 1],
        [2, 3]
      ]
    >
    iex> second
    #Nx.Tensor<
      s32[x: 2][y: 2]
      [
        [4, 5],
        [6, 7]
      ]
    >

## Vectorized tensors

Similarly to `to_list/1` and `to_binary/1`, `to_batched/2` will
ignore vectorization to perform calculations. Because the output
still contains tensors, however, they will still be vectorized.

    iex> t = Nx.iota({2, 2, 2}) |> Nx.vectorize(x: 2)
    iex> [first, second] = Nx.to_batched(t, 1) |> Enum.to_list()
    iex> first
    #Nx.Tensor<
      vectorized[x: 1]
      s32[2][2]
      [
        [
          [0, 1],
          [2, 3]
        ]
      ]
    >
    iex> second
    #Nx.Tensor<
      vectorized[x: 1]
      s32[2][2]
      [
        [
          [4, 5],
          [6, 7]
        ]
      ]
    >

    iex> t = Nx.iota({2, 2, 2}) |> Nx.vectorize(x: 2, y: 2)
    iex> [first, second] = Nx.to_batched(t, 1) |> Enum.to_list()
    iex> first
    #Nx.Tensor<
      vectorized[x: 1][y: 2]
      s32[2]
      [
        [
          [0, 1],
          [2, 3]
        ]
      ]
    >
    iex> second
    #Nx.Tensor<
      vectorized[x: 1][y: 2]
      s32[2]
      [
        [
          [4, 5],
          [6, 7]
        ]
      ]
    >

Same rules about uneven batches still apply:

    iex> t = Nx.iota({5, 2}, names: [:x, :y]) |> Nx.vectorize(:x)
    iex> [first, second, third] = Nx.to_batched(t, 2) |> Enum.to_list()
    iex> first
    #Nx.Tensor<
      vectorized[x: 2]
      s32[y: 2]
      [
        [0, 1],
        [2, 3]
      ]
    >
    iex> second
    #Nx.Tensor<
      vectorized[x: 2]
      s32[y: 2]
      [
        [4, 5],
        [6, 7]
      ]
    >
    iex> third
    #Nx.Tensor<
      vectorized[x: 2]
      s32[y: 2]
      [
        [8, 9],
        [0, 1]
      ]
    >

Because we're dealing with vectorized tensors, a vectorized
scalar tensor can also be batched.

    iex> t = Nx.tensor([1, 2, 3]) |> Nx.vectorize(:x)
    iex> [first, second] = t |> Nx.to_batched(2) |> Enum.to_list()
    iex> first
    #Nx.Tensor<
      vectorized[x: 2]
      s32
      [1, 2]
    >
    iex> second
    #Nx.Tensor<
      vectorized[x: 2]
      s32
      [3, 1]
    >

## to_number/1

Returns the underlying tensor as a number.

Negative infinity (-Inf), infinity (Inf), and "not a number" (NaN)
will be represented by the atoms `:neg_infinity`, `:infinity`, and
`:nan` respectively.

If the tensor has a dimension or is vectorized, it raises.

Note: This function cannot be used in `defn`.

## Examples

    iex> Nx.to_number(1)
    1

    iex> Nx.to_number(Nx.tensor([1.0, 2.0, 3.0]))
    ** (ArgumentError) cannot convert tensor of shape {3} to number

    iex> Nx.to_number(Nx.vectorize(Nx.tensor([1]), :x))
    ** (ArgumentError) cannot convert vectorized tensor with axes [x: 1] and shape {} to number

## as_type/2

Changes the type of a tensor.

Note conversion between float and integers truncates the
result. Consider using `round/1`, `floor/1`, or `ceil/1`
before casting from float to integer to guarantee consistent
behavior.

Casting from a higher precision may lead to an overflow
or underflow, which is platform and compiler dependent
behaviour.

Casting of non-finite types to integer types are handled
such as:

  * negative infinity becomes the minimum value for said type
  * positive infinity becomes the maximum value for said type
  * nan becomes zero

## Examples

    iex> Nx.as_type(Nx.tensor([0, 1, 2], names: [:data]), :f32)
    #Nx.Tensor<
      f32[data: 3]
      [0.0, 1.0, 2.0]
    >

    iex> Nx.as_type(Nx.tensor([0.0, 1.0, 2.0], names: [:data]), :bf16)
    #Nx.Tensor<
      bf16[data: 3]
      [0.0, 1.0, 2.0]
    >

    iex> Nx.as_type(Nx.tensor([0.0, 1.0, 2.0], names: [:data]), :s64)
    #Nx.Tensor<
      s64[data: 3]
      [0, 1, 2]
    >

Casting numbers as complex will return the corresponding complex with 0 imaginary component:

    iex> Nx.as_type(Nx.tensor([1, -2]), :c64)
    #Nx.Tensor<
      c64[2]
      [1.0+0.0i, -2.0+0.0i]
    >

Casting complex numbers will return their real parts as the target type:

    iex> Nx.as_type(Nx.tensor([Complex.new(1, 2), Complex.new(0, 3), Complex.new(4, 5)]), :f64)
    #Nx.Tensor<
      f64[3]
      [1.0, 0.0, 4.0]
    >

    iex> Nx.as_type(Nx.tensor([Complex.new(-1, 2), Complex.new(-2, 3), Complex.new(3, -4)]), :s64)
    #Nx.Tensor<
      s64[3]
      [-1, -2, 3]
    >

Casting of non-finite values to integer types convert to pre-determined
integer values:

    iex> non_finite = Nx.tensor([:infinity, :nan, :neg_infinity])
    iex> Nx.as_type(non_finite, :u8)
    #Nx.Tensor<
      u8[3]
      [255, 0, 0]
    >
    iex> Nx.as_type(non_finite, :s32)
    #Nx.Tensor<
      s32[3]
      [2147483647, 0, -2147483648]
    >

Non-finite values between float types are preserved:

    iex> non_finite = Nx.tensor([:infinity, :nan])
    iex> Nx.as_type(non_finite, :f64)
    #Nx.Tensor<
      f64[2]
      [Inf, NaN]
    >
    iex> Nx.as_type(non_finite, :f16)
    #Nx.Tensor<
      f16[2]
      [Inf, NaN]
    >

If the input is a numerical constant instead of a tensor, this is an
alias to `Nx.tensor(number, type: type)`. In the example below,
notice how precision is only lost if we pass a type which can't
represent the numerical input:

    iex> Nx.as_type(1.0e-128, :f32)
    #Nx.Tensor<
      f32
      0.0
    >
    iex> Nx.as_type(1.0e-128, :f64)
    #Nx.Tensor<
      f64
      1.0e-128
    >

## bitcast/2

Changes the type of a tensor, using a bitcast.

The width of input tensor's type must match the width
of the output type. `bitcast/1` does not change the
underlying tensor data, but instead changes how
the tensor data is viewed.

Machines with different floating-point representations
will give different results.

For complex numbers, the last axis will change in size
depending on whether you are upcasting or downcasting.

## Examples

    iex> t = Nx.bitcast(Nx.tensor([0, 0, 0], names: [:data], type: :s32), :f32)
    #Nx.Tensor<
      f32[data: 3]
      [0.0, 0.0, 0.0]
    >
    iex> Nx.bitcast(t, :s32)
    #Nx.Tensor<
      s32[data: 3]
      [0, 0, 0]
    >

    iex> t = Nx.vectorize(Nx.tensor([[0, -1], [1, -2], [2, -3]], type: :s8), :x)
    #Nx.Tensor<
      vectorized[x: 3]
      s8[2]
      [
        [0, -1],
        [1, -2],
        [2, -3]
      ]
    >
    iex> Nx.bitcast(t, :u8)
    #Nx.Tensor<
      vectorized[x: 3]
      u8[2]
      [
        [0, 255],
        [1, 254],
        [2, 253]
      ]
    >

## Error cases

    iex> Nx.bitcast(Nx.tensor([0, 1, 2], names: [:data], type: :s16), :f32)
    ** (ArgumentError) input type width must match new type width, got input type {:s, 16} and output type {:f, 32}

    iex> Nx.bitcast(Nx.tensor([0], type: :c64), :s64)
    ** (ArgumentError) Nx.bitcast/2 does not support complex inputs

    iex> Nx.bitcast(Nx.tensor([0], type: :s64), :c64)
    ** (ArgumentError) Nx.bitcast/2 does not support complex inputs

## reshape/3

Changes the shape of a tensor.

The new shape is either a tuple or a tensor which we will
retrieve the current shape from. The shapes must be compatible:
the product of each dimension in the shape must be equal.

You may specify one of the dimensions as `:auto`. Nx will compute
the size of the dimension based on the original shape and new shape.

Reshaping only changes the tensor metadata, it doesn't copy
the underlying structure.

Reshape is a destructive operation with respect to names. You
can optionally provide `:names` for each of the dimensions
in the reshaped tensor. If you do not provide `:names`, they
will be taken from the tensor the shape is taken from or
all of the dimension names will be set to `nil`.

## Examples

    iex> t = Nx.tensor([1, 2, 3, 4], names: [:x])
    iex> Nx.reshape(t, {2, 2}, names: [:x, :y])
    #Nx.Tensor<
      s32[x: 2][y: 2]
      [
        [1, 2],
        [3, 4]
      ]
    >

The shape can also be an existing tensor:

    iex> shape = Nx.tensor([[0], [0], [0], [0]], names: [:x, :y])
    iex> Nx.reshape(Nx.tensor([1, 2, 3, 4]), shape)
    #Nx.Tensor<
      s32[x: 4][y: 1]
      [
        [1],
        [2],
        [3],
        [4]
      ]
    >

Even a scalar can be transformed into a 3-dimensional tensor:

    iex> t = Nx.tensor(1)
    iex> Nx.reshape(t, {1, 1, 1}, names: [:x, :y, :z])
    #Nx.Tensor<
      s32[x: 1][y: 1][z: 1]
      [
        [
          [1]
        ]
      ]
    >

You can use `:auto` to infer dimension sizes. This is useful when you
don't know the size some dimension should be ahead of time:

    iex> t = Nx.tensor([[1, 2, 3], [4, 5, 6]])
    iex> Nx.reshape(t, {:auto, 2}, names: [:x, :y])
    #Nx.Tensor<
      s32[x: 3][y: 2]
      [
        [1, 2],
        [3, 4],
        [5, 6]
      ]
    >

## Vectorized tensors

Vectorized tensors have their inner shapes changed, keeping vectors unchanged.

    iex> t = Nx.tensor([[[1, 2, 3], [4, 5, 6]]]) |> Nx.vectorize(:x)
    iex> t.shape
    {2, 3}
    iex> Nx.reshape(t, {3, 2})
    #Nx.Tensor<
      vectorized[x: 1]
      s32[3][2]
      [
        [
          [1, 2],
          [3, 4],
          [5, 6]
        ]
      ]
    >

## rename/2

Adds (or overrides) the given names to the tensor.

## Examples

    iex> Nx.rename(Nx.iota({2, 3}), [:foo, :bar])
    #Nx.Tensor<
      s32[foo: 2][bar: 3]
      [
        [0, 1, 2],
        [3, 4, 5]
      ]
    >

## Vectorized tensors

Only the inner axis names are renamed. New names must not overlap with
vectorized names.

    iex> t = Nx.tensor([[1], [2], [3]], names: [nil, :y]) |> Nx.vectorize(:x)
    iex> Nx.rename(t, [:a])
    #Nx.Tensor<
      vectorized[x: 3]
      s32[a: 1]
      [
        [1],
        [2],
        [3]
      ]
    >
    iex> Nx.rename(t, [:x])
    ** (ArgumentError) name :x is already a name for a vectorized axis

## flatten/2

Flattens a n-dimensional tensor to a 1-dimensional tensor.

Flattening only changes the tensor metadata, it doesn't
copy the underlying structure.

Flatten is a destructive operation with respect to names.

## Examples

    iex> t = Nx.iota({2, 2, 2, 2})
    #Nx.Tensor<
      s32[2][2][2][2]
      [
        [
          [
            [0, 1],
            [2, 3]
          ],
          [
            [4, 5],
            [6, 7]
          ]
        ],
        [
          [
            [8, 9],
            [10, 11]
          ],
          [
            [12, 13],
            [14, 15]
          ]
        ]
      ]
    >
    iex> Nx.flatten(t)
    #Nx.Tensor<
      s32[16]
      [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
    >

And if the tensor is already 1-dimensional:

    iex> t = Nx.iota({16})
    #Nx.Tensor<
      s32[16]
      [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
    >
    iex> Nx.flatten(t)
    #Nx.Tensor<
      s32[16]
      [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
    >

You may also pass `:axes` to `Nx.flatten/2`, to specify which consecutive
axes to flatten:

    iex> t = Nx.iota({1, 2, 3})
    #Nx.Tensor<
      s32[1][2][3]
      [
        [
          [0, 1, 2],
          [3, 4, 5]
        ]
      ]
    >
    iex> Nx.flatten(t, axes: [1, 2])
    #Nx.Tensor<
      s32[1][6]
      [
        [0, 1, 2, 3, 4, 5]
      ]
    >

`:axes` must be consecutive, otherwise it will raise:

    iex> t = Nx.iota({1, 2, 3})
    #Nx.Tensor<
      s32[1][2][3]
      [
        [
          [0, 1, 2],
          [3, 4, 5]
        ]
      ]
    >
    iex> Nx.flatten(t, axes: [0, 2])
    ** (ArgumentError) flatten axes must be consecutive

## Vectorized tensors

Only the inner shape is flattened, leaving vectorized axes untouched.

    iex> t = Nx.iota({1, 3, 2, 2}) |> Nx.vectorize(:x) |> Nx.vectorize(:y)
    iex> Nx.flatten(t)
    #Nx.Tensor<
      vectorized[x: 1][y: 3]
      s32[4]
      [
        [
          [0, 1, 2, 3],
          [4, 5, 6, 7],
          [8, 9, 10, 11]
        ]
      ]
    >

## tile/2

Creates a new tensor by repeating the input tensor
along the given axes.

If the `tensor` has less dimensions than the repetitions given,
the tensor will grow in dimensionality.

If the `tensor` has more dimensions than the repetitions given,
tiling is done from the rightmost dimensions (i.e. if the input
shape is `{1,2,3}` and `repetitions = [2]`, the result is the same
as if `repetitions = [1,1,2]`).

## Examples

    iex> a = Nx.tensor([0, 1, 2])
    iex> Nx.tile(a, [2])
    #Nx.Tensor<
      s32[6]
      [0, 1, 2, 0, 1, 2]
    >
    iex> Nx.tile(a, [1, 2])
    #Nx.Tensor<
      s32[1][6]
      [
        [0, 1, 2, 0, 1, 2]
      ]
    >
    iex> Nx.tile(a, [2, 2])
    #Nx.Tensor<
      s32[2][6]
      [
        [0, 1, 2, 0, 1, 2],
        [0, 1, 2, 0, 1, 2]
      ]
    >
    iex> Nx.tile(a, [2, 1])
    #Nx.Tensor<
      s32[2][3]
      [
        [0, 1, 2],
        [0, 1, 2]
      ]
    >
    iex> Nx.tile(a, [2, 1, 2])
    #Nx.Tensor<
      s32[2][1][6]
      [
        [
          [0, 1, 2, 0, 1, 2]
        ],
        [
          [0, 1, 2, 0, 1, 2]
        ]
      ]
    >

    iex> b = Nx.tensor([[1,2],[3,4]])
    iex> Nx.tile(b, [2])
    #Nx.Tensor<
      s32[2][4]
      [
        [1, 2, 1, 2],
        [3, 4, 3, 4]
      ]
    >
    iex> Nx.tile(b, [2, 1])
    #Nx.Tensor<
      s32[4][2]
      [
        [1, 2],
        [3, 4],
        [1, 2],
        [3, 4]
      ]
    >
    iex> Nx.tile(b, [1, 2])
    #Nx.Tensor<
      s32[2][4]
      [
        [1, 2, 1, 2],
        [3, 4, 3, 4]
      ]
    >

    iex> c = Nx.tensor([1,2,3,4])
    iex> Nx.tile(c, [4,1])
    #Nx.Tensor<
      s32[4][4]
      [
        [1, 2, 3, 4],
        [1, 2, 3, 4],
        [1, 2, 3, 4],
        [1, 2, 3, 4]
      ]
    >

## Vectorized tensors

Like `reshape/2`, `tile/2` works on the shape, leaving vectors untouched.

    iex> t = Nx.vectorize(Nx.tensor([[1, 2, 3], [4, 5, 6]]), :x)
    iex> Nx.tile(t, [1, 3, 1])
    #Nx.Tensor<
      vectorized[x: 2]
      s32[1][3][3]
      [
        [
          [
            [1, 2, 3],
            [1, 2, 3],
            [1, 2, 3]
          ]
        ],
        [
          [
            [4, 5, 6],
            [4, 5, 6],
            [4, 5, 6]
          ]
        ]
      ]
    >

## Error cases

    iex> Nx.tile(Nx.tensor([1,2]), 1.0)
    ** (ArgumentError) repetitions must be a list of integers, got: 1.0

    iex> Nx.tile(Nx.tensor([1,2]), [1, 1.0])
    ** (ArgumentError) repetitions must be a list of integers, got: [1, 1.0]

    iex> Nx.tile(Nx.tensor([1,2]), nil)
    ** (ArgumentError) repetitions must be a list of integers, got: nil

## new_axis/3

Adds a new `axis` of size 1 with optional `name`.

## Examples

    iex> t = Nx.tensor([[1, 2, 3], [4, 5, 6]])
    iex> Nx.new_axis(t, 0, :new)
    #Nx.Tensor<
      s32[new: 1][2][3]
      [
        [
          [1, 2, 3],
          [4, 5, 6]
        ]
      ]
    >
    iex> Nx.new_axis(t, 1, :new)
    #Nx.Tensor<
      s32[2][new: 1][3]
      [
        [
          [1, 2, 3]
        ],
        [
          [4, 5, 6]
        ]
      ]
    >
    iex> Nx.new_axis(t, 2, :new)
    #Nx.Tensor<
      s32[2][3][new: 1]
      [
        [
          [1],
          [2],
          [3]
        ],
        [
          [4],
          [5],
          [6]
        ]
      ]
    >

Axis can also be negative, which will start from the back:

    iex> t = Nx.tensor([[1, 2, 3], [4, 5, 6]])
    iex> Nx.new_axis(t, -1, :new)
    #Nx.Tensor<
      s32[2][3][new: 1]
      [
        [
          [1],
          [2],
          [3]
        ],
        [
          [4],
          [5],
          [6]
        ]
      ]
    >

## Vectorized tensors

Similarly to `reshape/2`, vectorized tensors will have their
vectors unchanged. The examples below show that the new axes
only affect the tensor shape.

    iex> t = Nx.tensor([1]) |> Nx.vectorize(:x)
    #Nx.Tensor<
      vectorized[x: 1]
      s32
      [1]
    >
    iex> t = Nx.new_axis(t, -1, :new)
    #Nx.Tensor<
      vectorized[x: 1]
      s32[new: 1]
      [
        [1]
      ]
    >
    iex> Nx.new_axis(t, 0)
    #Nx.Tensor<
      vectorized[x: 1]
      s32[1][new: 1]
      [
        [
          [1]
        ]
      ]
    >

## squeeze/2

Squeezes the given size `1` dimensions out of the tensor.

If no axes are given, squeezes all size `1` dimensions
from the tensor.

While this is equivalent to a reshape which eliminates
the size `1` axes, squeeze preserves important information
about which axes were squeezed out which can then be used
later on in transformations.

## Examples

    iex> Nx.squeeze(Nx.tensor([[[[[1]]]]]))
    #Nx.Tensor<
      s32
      1
    >

    iex> Nx.squeeze(Nx.tensor([[[[1]]], [[[2]]]], names: [:x, :y, :z, :i]))
    #Nx.Tensor<
      s32[x: 2]
      [1, 2]
    >

    iex> Nx.squeeze(Nx.tensor([[1, 2, 3]], names: [:x, :y]), axes: [:x])
    #Nx.Tensor<
      s32[y: 3]
      [1, 2, 3]
    >

    iex> Nx.squeeze(Nx.tensor([[1], [2]], names: [:x, :y]), axes: [:y])
    #Nx.Tensor<
      s32[x: 2]
      [1, 2]
    >

## Vectorized tensors

`squeeze/2` operates on the tensor's shape, leaving vectorized axes untouched.

    iex> t = Nx.tensor([[[[[1], [2], [3]]]]]) |> Nx.vectorize(:x)
    #Nx.Tensor<
      vectorized[x: 1]
      s32[1][1][3][1]
      [
        [
          [
            [
              [1],
              [2],
              [3]
            ]
          ]
        ]
      ]
    >
    iex> Nx.squeeze(t)
    #Nx.Tensor<
      vectorized[x: 1]
      s32[3]
      [
        [1, 2, 3]
      ]
    >
    iex> Nx.squeeze(t, axes: [0, 1])
    #Nx.Tensor<
      vectorized[x: 1]
      s32[3][1]
      [
        [
          [1],
          [2],
          [3]
        ]
      ]
    >

## Error cases

    iex> Nx.squeeze(Nx.tensor([[1, 2, 3], [4, 5, 6]]), axes: [1])
    ** (ArgumentError) cannot squeeze dimensions whose sizes are not 1, got 3 for dimension 1

    iex> Nx.squeeze(Nx.tensor([[[[[1]]]]]), axes: [0, 0])
    ** (ArgumentError) axes [0, 0] must be unique integers between 0 and 4

## broadcast/3

Broadcasts `tensor` to the given `broadcast_shape`.

The new shape is either a tuple or a tensor which we will
retrieve the current shape from. The broadcast shape must
be of equal or higher rank than the current shape.

An optional `:axes` can be given to customize how broadcasting
happens. `axes` must be a list with the same length as the
tensor shape. Each `axis` in the list maps to the dimension
in the broadcast shape that must match. For example, an axis
of `[1, 2]` says the 0 dimension of the tensor matches to
the 1 dimension of the broadcast shape and the 1 dimension
of the tensor matches the 2 dimension of the broadcast shape.
Each matching dimension must either be 1, for implicit
broadcasting, or match the dimension in the broadcast shape.

Broadcasting is destructive with respect to names. You can
optionally provide new `:names` for the new tensor. If you
pass a tensor with named dimensions, the new tensor will
inherit names from that tensor.

## Examples

### Without axes

    iex> Nx.broadcast(1, {1, 2, 3})
    #Nx.Tensor<
      s32[1][2][3]
      [
        [
          [1, 1, 1],
          [1, 1, 1]
        ]
      ]
    >

    iex> Nx.broadcast(Nx.tensor([[1], [2]], names: [:x, :y]), Nx.tensor([[10, 20], [30, 40]], names: [:i, :j]))
    #Nx.Tensor<
      s32[i: 2][j: 2]
      [
        [1, 1],
        [2, 2]
      ]
    >

    iex> Nx.broadcast(Nx.tensor([[1, 2]], names: [:x, :y]), Nx.tensor([[10, 20], [30, 40]], names: [:i, :j]))
    #Nx.Tensor<
      s32[i: 2][j: 2]
      [
        [1, 2],
        [1, 2]
      ]
    >

Note that, even if there is no broadcasting because the
shape is the same, names are discarded if none are given:

    iex> Nx.broadcast(Nx.iota({2, 2}, names: [:x, :y]), {2, 2})
    #Nx.Tensor<
      s32[2][2]
      [
        [0, 1],
        [2, 3]
      ]
    >

    iex> Nx.broadcast(Nx.iota({2, 2}, names: [:x, :y]), {2, 2}, names: [:i, :j])
    #Nx.Tensor<
      s32[i: 2][j: 2]
      [
        [0, 1],
        [2, 3]
      ]
    >

### With axes

Using the default broadcast rules, we cannot broadcast a
tensor of shape (3) to the shape (3, 2), because the lower
dimensions must match. But with `Nx.broadcast/3` we can
configure how the dimensions match:

    iex> t = Nx.tensor([1, 2, 3])
    iex> Nx.broadcast(t, {3, 2}, axes: [0], names: [:x, :y])
    #Nx.Tensor<
      s32[x: 3][y: 2]
      [
        [1, 1],
        [2, 2],
        [3, 3]
      ]
    >

Or a more complex example:

    iex> t = Nx.tensor([1, 2, 3])
    iex> Nx.broadcast(t, {2, 3, 2}, axes: [1], names: [:x, :y, :z])
    #Nx.Tensor<
      s32[x: 2][y: 3][z: 2]
      [
        [
          [1, 1],
          [2, 2],
          [3, 3]
        ],
        [
          [1, 1],
          [2, 2],
          [3, 3]
        ]
      ]
    >

## Vectorized tensors

Vectorized axes remain unchanged, and normal broadcast rules apply otherwise.

    iex> a = Nx.tensor([[[1, 2, 3]], [[4, 5, 6]]]) |> Nx.vectorize(:x)
    iex> Nx.broadcast(a, {2, 3})
    #Nx.Tensor<
      vectorized[x: 2]
      s32[2][3]
      [
        [
          [1, 2, 3],
          [1, 2, 3]
        ],
        [
          [4, 5, 6],
          [4, 5, 6]
        ]
      ]
    >

For tensors as shapes, the broadcast will only take the shape in consideration.

    iex> a = Nx.tensor([[1, 2, 3], [4, 5, 6]]) |> Nx.vectorize(:x)
    #Nx.Tensor<
      vectorized[x: 2]
      s32[3]
      [
        [1, 2, 3],
        [4, 5, 6]
      ]
    >
    iex> b = Nx.tensor([[[1, 2, 3], [4, 5, 6]]], names: [nil, nil, :y]) |> Nx.vectorize(:a)
    #Nx.Tensor<
      vectorized[a: 1]
      s32[2][y: 3]
      [
        [
          [1, 2, 3],
          [4, 5, 6]
        ]
      ]
    >
    iex> Nx.broadcast(a, b, axes: [1], names: [:i, :j])
    #Nx.Tensor<
      vectorized[x: 2]
      s32[i: 2][j: 3]
      [
        [
          [1, 2, 3],
          [1, 2, 3]
        ],
        [
          [4, 5, 6],
          [4, 5, 6]
        ]
      ]
    >

## pad/3

Pads a tensor with a given value.

You must specify a padding configuration. A padding
configuration is a list of tuples consisting of
`{pad_width_low, pad_width_high, pad_width_interior}`
for each dimension in the input tensor. The padding
configuration must be of the same length as the tensor shape.

Padding widths can be negative. If they are negative,
the tensor is clipped on either end according to the
padding width. Interior padding widths cannot be negative.

See also: `reflect/2`

## Examples

    iex> Nx.pad(Nx.tensor(1), 0, [])
    #Nx.Tensor<
      s32
      1
    >

    iex> Nx.pad(Nx.tensor([1, 2, 3], names: [:data]), 0, [{1, 1, 0}])
    #Nx.Tensor<
      s32[data: 5]
      [0, 1, 2, 3, 0]
    >

    iex> Nx.pad(Nx.tensor([[1, 2, 3], [4, 5, 6]]), 0, [{0, 0, 1}, {0, 0, 1}])
    #Nx.Tensor<
      s32[3][5]
      [
        [1, 0, 2, 0, 3],
        [0, 0, 0, 0, 0],
        [4, 0, 5, 0, 6]
      ]
    >

    iex> Nx.pad(Nx.tensor([[1, 2, 3], [4, 5, 6]]), 0, [{1, 1, 0}, {1, 1, 0}])
    #Nx.Tensor<
      s32[4][5]
      [
        [0, 0, 0, 0, 0],
        [0, 1, 2, 3, 0],
        [0, 4, 5, 6, 0],
        [0, 0, 0, 0, 0]
      ]
    >

    iex> tensor = Nx.tensor([[[1, 2], [3, 4]], [[5, 6], [7, 8]]])
    iex> Nx.pad(tensor, 0, [{0, 2, 0}, {1, 1, 0}, {1, 0, 0}])
    #Nx.Tensor<
      s32[4][4][3]
      [
        [
          [0, 0, 0],
          [0, 1, 2],
          [0, 3, 4],
          [0, 0, 0]
        ],
        [
          [0, 0, 0],
          [0, 5, 6],
          [0, 7, 8],
          [0, 0, 0]
        ],
        [
          [0, 0, 0],
          [0, 0, 0],
          [0, 0, 0],
          [0, 0, 0]
        ],
        [
          [0, 0, 0],
          [0, 0, 0],
          [0, 0, 0],
          [0, 0, 0]
        ]
      ]
    >

    iex> tensor = Nx.tensor([[[1, 2], [3, 4]], [[5, 6], [7, 8]]])
    iex> Nx.pad(tensor, 0, [{1, 0, 0}, {1, 1, 0}, {0, 1, 0}])
    #Nx.Tensor<
      s32[3][4][3]
      [
        [
          [0, 0, 0],
          [0, 0, 0],
          [0, 0, 0],
          [0, 0, 0]
        ],
        [
          [0, 0, 0],
          [1, 2, 0],
          [3, 4, 0],
          [0, 0, 0]
        ],
        [
          [0, 0, 0],
          [5, 6, 0],
          [7, 8, 0],
          [0, 0, 0]
        ]
      ]
    >

    iex> tensor = Nx.tensor([[[1.0, 2.0], [3.0, 4.0]], [[5.0, 6.0], [7.0, 8.0]]])
    iex> Nx.pad(tensor, 0.0, [{1, 2, 0}, {1, 0, 0}, {0, 1, 0}])
    #Nx.Tensor<
      f32[5][3][3]
      [
        [
          [0.0, 0.0, 0.0],
          [0.0, 0.0, 0.0],
          [0.0, 0.0, 0.0]
        ],
        [
          [0.0, 0.0, 0.0],
          [1.0, 2.0, 0.0],
          [3.0, 4.0, 0.0]
        ],
        [
          [0.0, 0.0, 0.0],
          [5.0, 6.0, 0.0],
          [7.0, 8.0, 0.0]
        ],
        [
          [0.0, 0.0, 0.0],
          [0.0, 0.0, 0.0],
          [0.0, 0.0, 0.0]
        ],
        [
          [0.0, 0.0, 0.0],
          [0.0, 0.0, 0.0],
          [0.0, 0.0, 0.0]
        ]
      ]
    >

    iex> Nx.pad(Nx.tensor([0, 1, 2, 3, 0]), 0, [{-1, -1, 0}])
    #Nx.Tensor<
      s32[3]
      [1, 2, 3]
    >

    iex> tensor = Nx.tensor([
    ...>   [[0, 0, 0], [0, 0, 0], [0, 0, 0], [0, 0, 0]],
    ...>   [[0, 0, 0], [1, 2, 0], [3, 4, 0], [0, 0, 0]],
    ...>   [[0, 0, 0], [5, 6, 0], [7, 8, 0], [0, 0, 0]]
    ...> ])
    iex> Nx.pad(tensor, 0, [{-1, 0, 0}, {-1, -1, 0}, {0, -1, 0}])
    #Nx.Tensor<
      s32[2][2][2]
      [
        [
          [1, 2],
          [3, 4]
        ],
        [
          [5, 6],
          [7, 8]
        ]
      ]
    >

    iex> tensor = Nx.tensor([[0, 1, 2, 3], [0, 4, 5, 6]])
    iex> Nx.pad(tensor, 0, [{0, 0, 0}, {-1, 1, 0}])
    #Nx.Tensor<
      s32[2][4]
      [
        [1, 2, 3, 0],
        [4, 5, 6, 0]
      ]
    >

    iex> tensor = Nx.tensor([[0, 1, 2], [3, 4, 5]], type: :f32)
    iex> Nx.pad(tensor, 0, [{-1, 2, 0}, {1, -1, 0}])
    #Nx.Tensor<
      f32[3][3]
      [
        [0.0, 3.0, 4.0],
        [0.0, 0.0, 0.0],
        [0.0, 0.0, 0.0]
      ]
    >

## Vectorized tensors

Like with the non-vectorized case, `pad_value` must be a non-vectorized scalar tensor.
Vectorized axes remain unchanged.

    iex> t = Nx.tensor([[1], [2], [3]], names: [nil, :data]) |> Nx.vectorize(:x)
    iex> Nx.pad(t, 0, [{1, 1, 0}])
    #Nx.Tensor<
      vectorized[x: 3]
      s32[data: 3]
      [
        [0, 1, 0],
        [0, 2, 0],
        [0, 3, 0]
      ]
    >

## type/1

Returns the type of the tensor.

See `Nx.Type` for more information.

## Examples

    iex> Nx.type(Nx.tensor([1, 2, 3]))
    {:s, 32}

    iex> Nx.type(Nx.tensor([1, 2, 3], type: :f32))
    {:f, 32}

    iex> Nx.type(1)
    {:s, 32}

    iex> Nx.type(1.0)
    {:f, 32}

## compatible?/2

Checks if two tensors have the same shape, type, and compatible names.

The data in the tensor is ignored.

Note: This function cannot be used in `defn`.

## Examples

    iex> Nx.compatible?(Nx.iota({3, 2}), Nx.iota({3, 2}))
    true

    iex> Nx.compatible?(Nx.iota({3, 2}), Nx.iota({3, 2}, names: [:rows, :columns]))
    true

    iex> Nx.compatible?(
    ...>   Nx.iota({3, 2}, names: [:rows, nil]),
    ...>   Nx.iota({3, 2}, names: [nil, :columns])
    ...> )
    true

    iex> Nx.compatible?(
    ...>   Nx.iota({3, 2}, names: [:foo, :bar]),
    ...>   Nx.iota({3, 2}, names: [:rows, :columns])
    ...> )
    false

    iex> Nx.compatible?(Nx.iota({3, 2}), Nx.iota({2, 3}))
    false

    iex> Nx.compatible?(Nx.iota({2, 2}), Nx.iota({2, 2}, type: :f32))
    false

Using collections:

    iex> Nx.compatible?({Nx.iota({3, 2}), {1, 2}}, {Nx.iota({3, 2}), {3, 4}})
    true

    iex> Nx.compatible?(%{foo: Nx.iota({3, 2})}, %{foo: Nx.iota({3, 2})})
    true

    iex> Nx.compatible?(%{foo: Nx.iota({3, 2})}, %{bar: Nx.iota({3, 2})})
    false

## Vectorized tensors

Same compatibility criteria applies to vectorized tensors, but there's
the additional requirement that vectorized axes must be the same in both
tensors.

    iex> Nx.compatible?(Nx.tensor([1, 2]) |> Nx.vectorize(:x), Nx.tensor([3, 4]) |> Nx.vectorize(:x))
    true
    iex> Nx.compatible?(Nx.tensor([1, 2, 3]) |> Nx.vectorize(:x), Nx.tensor([1, 2]) |> Nx.vectorize(:x))
    false
    iex> Nx.compatible?(Nx.tensor([1]) |> Nx.vectorize(:x), Nx.tensor([1, 2]) |> Nx.vectorize(:y))
    false

## shape/1

Returns the shape of the tensor as a tuple.

The size of this tuple gives the rank of the tensor.

If a shape as a tuple is given, it returns the shape itself.

## Examples

    iex> Nx.shape(Nx.tensor(1))
    {}

    iex> Nx.shape(Nx.tensor([[1, 2, 3], [4, 5, 6]]))
    {2, 3}

    iex> Nx.shape(1)
    {}

    iex> Nx.shape({1, 2, 3})
    {1, 2, 3}

## rank/1

Returns the rank of a tensor.

If a tuple is given as a shape, it computes the rank
of the given tuple.

## Examples

    iex> Nx.rank(Nx.tensor(1))
    0

    iex> Nx.rank(Nx.tensor([[1, 2, 3], [4, 5, 6]]))
    2

    iex> Nx.rank(1)
    0

    iex> Nx.rank({1, 2, 3})
    3

## axis_size/2

Returns the size of a given axis of a tensor.

It accepts either an atom as the name or an integer as the axis.
It raises if the axis/name does not exist.

## Examples

    iex> Nx.axis_size(Nx.iota({100, 10, 20}), 0)
    100

    iex> Nx.axis_size(Nx.iota({100, 10, 20}, names: [:batch, :x, :y]), :y)
    20

## axis_index/2

Returns the index of the given axis in the tensor.

## Examples

    iex> Nx.axis_index(Nx.iota({100, 10, 20}), 0)
    0

    iex> Nx.axis_index(Nx.iota({100, 10, 20}), -1)
    2

    iex> Nx.axis_index(Nx.iota({100, 10, 20}, names: [:batch, :x, :y]), :x)
    1

## Error cases

    iex> Nx.axis_index(Nx.iota({100, 10, 20}), 3)
    ** (ArgumentError) given axis (3) invalid for shape with rank 3

    iex> Nx.axis_index(Nx.iota({100, 10, 20}, names: [:batch, :x, :y]), :z)
    ** (ArgumentError) name :z not found in tensor with names [:batch, :x, :y]

## size/1

Returns the number of elements in the tensor.

If a tuple is given, it returns the number of elements in a tensor with that shape.
Vectorized tensors will not include vectorized axes sizes. See `flat_size/1`.

## Examples

    iex> Nx.size(Nx.tensor([[1, 2, 3], [4, 5, 6]]))
    6

    iex> Nx.size(1)
    1

    iex> Nx.size({1, 2, 3, 2})
    12

    iex> Nx.size(Nx.vectorize(Nx.iota({4, 3, 2}), :x))
    6

## flat_size/1

Returns the number of elements in the tensor (including vectorized axes).

See also: `size/1`

## Examples

    iex> Nx.flat_size(Nx.tensor([[1, 2, 3], [4, 5, 6]]))
    6

    iex> Nx.flat_size(10)
    1

    iex> t = Nx.iota({4, 3, 2})
    iex> v1 = Nx.vectorize(t, :x)
    iex> Nx.flat_size(v1)
    24
    iex> Nx.flat_size(Nx.vectorize(v1, :y))
    24

## byte_size/1

Returns the byte size of the data in the tensor
computed from its shape and type.

If the tensor has s2/s4/u2/u4 types, the value
will be rounded down. Consider using `bit_size/1`
instead.

## Examples

    iex> Nx.byte_size(Nx.tensor([[1, 2, 3], [4, 5, 6]]))
    24
    iex> Nx.byte_size(Nx.tensor([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]]))
    24
    iex> Nx.byte_size(Nx.tensor([[1, 2, 3], [4, 5, 6]], type: :u8))
    6
    iex> Nx.byte_size(1)
    4

Vectorized tensors account for all elements

    iex> Nx.byte_size(Nx.tensor([[1, 2], [3, 4]]) |> Nx.vectorize(:x))
    16

## bit_size/1

Returns the bit size of the data in the tensor
computed from its shape and type.

## Examples

    iex> Nx.bit_size(Nx.tensor([[1, 2, 3], [4, 5, 6]]))
    192
    iex> Nx.bit_size(Nx.tensor([[1, 2, 3], [4, 5, 6]], type: :u8))
    48
    iex> Nx.bit_size(Nx.tensor([[1, 2, 3], [3, 2, 1]], type: :u2))
    12
    iex> Nx.bit_size(1)
    32

Vectorized tensors account for all elements

    iex> Nx.bit_size(Nx.tensor([[1, 2], [3, 4]]) |> Nx.vectorize(:x))
    128

## axes/1

Returns all of the axes in a tensor.

If a shape is given, it returns the axes for the given shape.

## Examples

    iex> Nx.axes(Nx.tensor([[1, 2, 3], [4, 5, 6]]))
    [0, 1]

    iex> Nx.axes(1)
    []

    iex> Nx.axes({1, 2, 3})
    [0, 1, 2]

## names/1

Returns all of the names in a tensor.

## Examples

    iex> Nx.names(Nx.tensor([[1, 2, 3], [4, 5, 6]], names: [:batch, :data]))
    [:batch, :data]

    iex> Nx.names(Nx.tensor([1, 2, 3]))
    [nil]

    iex> Nx.names(5)
    []

## default_backend/1

Sets the given `backend` as default in the **current process**.

The default backend is stored only in the process dictionary.
This means if you start a separate process, such as `Task`,
the default backend must be set on the new process too.

Due to this reason, this function is mostly used for scripting
and testing. In your applications, you must prefer to set the
backend in your config files:

    config :nx, :default_backend, {EXLA.Backend, device: :cuda}

In your notebooks and on `Mix.install/2`, you might:

    Mix.install(
      [
        {:nx, ">= 0.0.0"}
      ],
      config: [nx: [default_backend: {EXLA.Backend, device: :cuda}]]
    )

Or use `Nx.global_default_backend/1` as it changes the
default backend on all processes.

The function returns the value that was previously set as backend.

Note: This function cannot be used in `defn`.

## Examples

    Nx.default_backend({EXLA.Backend, device: :cuda})
    #=> {Nx.BinaryBackend, []}

## global_default_backend/1

Sets the default backend globally.

You must avoid calling this function at runtime. It is mostly
useful during scripts or code notebooks to set a default.

If you need to configure a global default backend in your
applications, it is generally preferred to do so in your
`config/*.exs` files:

    config :nx, :default_backend, {EXLA.Backend, []}

In your notebooks and on `Mix.install/2`, you might:

    Mix.install(
      [
        {:nx, ">= 0.0.0"}
      ],
      config: [nx: [default_backend: {EXLA.Backend, device: :cuda}]]
    )

The function returns the value that was previously set as global backend.

## default_backend/0

Gets the default backend for the current process.

Note: This function cannot be used in `defn`.

## with_default_backend/2

Invokes the given function temporarily setting `backend` as the
default backend.

## backend_copy/2

Copies data to the given backend.

If a backend is not given, `Nx.Tensor` is used, which means
the given tensor backend will pick the most appropriate
backend to copy the data to.

Note this function keeps the data in the original backend.
Therefore, use this function with care, as it may duplicate
large amounts of data across backends. Generally speaking,
you may want to use `backend_transfer/2`, unless you explicitly
want to copy the data.

Note:

* `Nx.default_backend/1` does not affect the behaviour of
this function.
* This function cannot be used in `defn`.

## Examples

    iex> Nx.backend_copy(Nx.tensor([[1, 2, 3], [4, 5, 6]]))
    #Nx.Tensor<
      s32[2][3]
      [
        [1, 2, 3],
        [4, 5, 6]
      ]
    >

## backend_transfer/2

Transfers data to the given backend.

This operation can be seen as an equivalent to `backend_copy/3`
followed by a `backend_deallocate/1` on the initial tensor:

    new_tensor = Nx.backend_copy(old_tensor, new_backend)
    Nx.backend_deallocate(old_tensor)

If a backend is not given, `Nx.Tensor` is used, which means
the given tensor backend will pick the most appropriate
backend to transfer to.

For Elixir's builtin tensor, transferring to another backend
will call `new_backend.from_binary(tensor, binary, opts)`.
Transferring from a mutable backend, such as GPU memory,
implies the data is copied from the GPU to the Erlang VM
and then deallocated from the device.

Note:

* `Nx.default_backend/1` does not affect the behaviour of this function.
* This function cannot be used in `defn`.

## Examples

Transfer a tensor to an EXLA device backend, stored in the GPU:

    device_tensor = Nx.backend_transfer(tensor, {EXLA.Backend, client: :cuda})

Transfer the device tensor back to an Elixir tensor:

    tensor = Nx.backend_transfer(device_tensor)

## backend_deallocate/1

Deallocates data in a device.

It returns either `:ok` or `:already_deallocated`.

Note: This function cannot be used in `defn`.

## vectorize/2

Transforms a tensor into a vectorized tensor.

Each vectorization removes the leading axes from the shape and appends them to
the `:vectorized_axes` list for the tensor.

The vectorization specification can be a list of atoms or `{atom, pos_integer}`
pairs. If a single atom is given, it behaves as a single-element list.
The atom names the vectorized axes. If a pair is given, we also verify
that the given size matches the size of the to-be-vectorized axis.

In the examples below, we discuss in more detail how a vectorized tensor works.

## Examples

In this first example, we turn a `{2, 3}`-shaped tensor into a vectorized tensor
with 1 vectorized axes and rank 1 shape, `{3}`, and then into a vectorized tensor
with 2 vectorized axes and rank 0 shape.

    iex> t = Nx.iota({2, 3})
    iex> vectorized = Nx.vectorize(t, :first)
    #Nx.Tensor<
      vectorized[first: 2]
      s32[3]
      [
        [0, 1, 2],
        [3, 4, 5]
      ]
    >
    iex> Nx.vectorize(vectorized, :second)
    #Nx.Tensor<
      vectorized[first: 2][second: 3]
      s32
      [
        [0, 1, 2],
        [3, 4, 5]
      ]
    >

You can also vectorize multiple axes at once by passing a list,
as seen in the examples below. The first example doesn't validate
sizes. The second ensures the second axis has size `3`.

    iex> t = Nx.iota({2, 3})
    iex> v1 = Nx.vectorize(t, [:first, :second])
    #Nx.Tensor<
      vectorized[first: 2][second: 3]
      s32
      [
        [0, 1, 2],
        [3, 4, 5]
      ]
    >
    iex> v2 = Nx.vectorize(t, [:first, second: 3])
    iex> v1 == v2
    true

A vectorized tensor can be thought of as a tensor that signals
to Nx that any operation applied on it must instead be applied
to each individual entry for the vectorized axis.
Nested vectorizations just apply this idea recursively, ultimately
applying the operation to each non-vectorized entry.

In the following example, notice that you don't need to have the
second argument shaped in a way that can be broadcasted, because
vectorization handles that automatically.

In the example below, shape `{4}` isn't broadcast-compatible with `{2}`:

    iex> Nx.add(Nx.tensor([4, 3, 2, 1]), Nx.tensor([0, 1]))
    ** (ArgumentError) cannot broadcast tensor of dimensions {4} to {2}

If we want to add the two tensors, normally we would need to reshape
to signal which axis are broadcasted together:

    iex> left = Nx.tensor([4, 3, 2, 1]) |> Nx.reshape({4, 1})
    iex> right = Nx.tensor([0, 1]) |> Nx.reshape({1, 2})
    iex> Nx.add(left, right)
    #Nx.Tensor<
      s32[4][2]
      [
        [4, 5],
        [3, 4],
        [2, 3],
        [1, 2]
      ]
    >

However, it `vectorize/1` simplifies this process. We can instead
signal that each entry on the `left` tensor will be treated as an
individual tensor, effectively forcing the same broadcast to happen.
In fact, you can think of the following code as a series of
additions between tensors of shapes `{}` and `{2}` respectively.

    iex> vectorized = Nx.vectorize(Nx.tensor([4, 3, 2, 1]), :x)
    #Nx.Tensor<
      vectorized[x: 4]
      s32
      [4, 3, 2, 1]
    >
    iex> Nx.add(vectorized, Nx.tensor([0, 1]))
    #Nx.Tensor<
      vectorized[x: 4]
      s32[2]
      [
        [4, 5],
        [3, 4],
        [2, 3],
        [1, 2]
      ]
    >

## Containers

Containers are also supported:

    iex> input = {Nx.tensor([1]), %{a: Nx.tensor([2])}}
    iex> {t1, %{a: t2}} = Nx.vectorize(input, x: 1)
    iex> t1
    #Nx.Tensor<
      vectorized[x: 1]
      s32
      [1]
    >
    iex> t2
    #Nx.Tensor<
      vectorized[x: 1]
      s32
      [2]
    >

## Error cases

    iex> Nx.vectorize(Nx.tensor(1), :x)
    ** (ArgumentError) cannot vectorize tensor of rank 0

    iex> Nx.vectorize(Nx.tensor([1]), [:x, :y])
    ** (ArgumentError) number of vectorized axes must not be greater than the shape size

    iex> Nx.vectorize(Nx.tensor([1]), [x: 2])
    ** (ArgumentError) expected vectorized axis :x to have size 2, got 1

    iex> Nx.vectorize(Nx.tensor([[1]]), [:x, "y"])
    ** (ArgumentError) expected vectorized axis specification to be an atom or a tuple of {atom, pos_integer}, got: "y"

    iex> Nx.vectorize(Nx.tensor([[1]], names: [:x, :y]), [:y])
    ** (ArgumentError) cannot use name :y for new vectorized axes because there's already an axis with the same name

    iex> t = Nx.vectorize(Nx.tensor([[1]]), :x)
    iex> Nx.vectorize(t, :x)
    ** (ArgumentError) cannot use name :x for new vectorized axes because there's already a vectorized axis with the same name

## devectorize/2

Transforms a vectorized tensor back into a regular tensor.

## Options

  * `:keep_names` - a boolean indicating whether
    vectorized axes' names should be turned into the new
    axes' names. Defaults to `true`.

## Examples

    iex> t = Nx.iota({1, 2, 3}) |> Nx.vectorize(:x) |> Nx.vectorize(:y)
    #Nx.Tensor<
      vectorized[x: 1][y: 2]
      s32[3]
      [
        [
          [0, 1, 2],
          [3, 4, 5]
        ]
      ]
    >
    iex> Nx.devectorize(t)
    #Nx.Tensor<
      s32[x: 1][y: 2][3]
      [
        [
          [0, 1, 2],
          [3, 4, 5]
        ]
      ]
    >
    iex> Nx.devectorize(t, keep_names: false)
    #Nx.Tensor<
      s32[1][2][3]
      [
        [
          [0, 1, 2],
          [3, 4, 5]
        ]
      ]
    >

## Containers

Containers are also supported:

    iex> input = {1, %{a: Nx.iota({3}, vectorized_axes: [x: 1])}}
    iex> {t1, %{a: t2}} = Nx.devectorize(input)
    iex> t1
    #Nx.Tensor<
      s32
      1
    >
    iex> t2
    #Nx.Tensor<
      s32[x: 1][3]
      [
        [0, 1, 2]
      ]
    >

## reshape_vectors/2

Reshapes input tensors so that they are all vectorized with the same vectors.

For vectors with the same name to be compatible, they need to either
have the same size or one must be of size 1.

## Options

  * `:align_ranks` - boolean that indicates whether the inner
    shapes should be aligned to the maximum rank of the inputs.
    That is, 1-sized leading dimensions are added so
    that all tensors have the same rank in the output.
    This only applies in case one of the inputs is vectorized.

## Examples

Two vectors of the same name are compatible if they have the same sizes or if either has size 1.

    iex> x = Nx.tensor([1, 2, 3]) |> Nx.vectorize(:x)
    iex> xy = Nx.tensor([[[5]], [[6]]]) |> Nx.vectorize(:y) |> Nx.vectorize(:x)
    iex> [x, xy] = Nx.reshape_vectors([x, xy])
    iex> x.vectorized_axes
    [x: 3, y: 1]
    iex> xy.vectorized_axes
    [x: 1, y: 2]

The resulting tensors will all present the combined vectors in the
same order in which each unique vector appears in the input.
The example below shows how this behaves for a pair of tensors.

    iex> x = Nx.tensor([1, 2, 3]) |> Nx.vectorize(:x)
    iex> y = Nx.tensor([4]) |> Nx.vectorize(:y)
    iex> [xv, yv] = Nx.reshape_vectors([x, y])
    iex> xv.vectorized_axes
    [x: 3, y: 1]
    iex> yv.vectorized_axes
    [x: 1, y: 1]
    iex> [yv, xv] = Nx.reshape_vectors([y, x])
    iex> xv.vectorized_axes
    [y: 1, x: 3]
    iex> yv.vectorized_axes
    [y: 1, x: 1]

The `:align_ranks` option controls whether the resulting tensors should end up
with the same rank, which helps with broadcasting in some cases.

    iex> x = 1
    iex> y = Nx.tensor([[[1], [1]], [[2], [2]], [[3], [3]]]) |> Nx.vectorize(:y)
    iex> [xv, yv] = Nx.reshape_vectors([x, y])
    iex> xv
    #Nx.Tensor<
      vectorized[y: 1]
      s32
      [1]
    >
    iex> yv
    #Nx.Tensor<
      vectorized[y: 3]
      s32[2][1]
      [
        [
          [1],
          [1]
        ],
        [
          [2],
          [2]
        ],
        [
          [3],
          [3]
        ]
      ]
    >
    iex> [xv, _yv] = Nx.reshape_vectors([x, y], align_ranks: true)
    iex> xv
    #Nx.Tensor<
      vectorized[y: 1]
      s32[1][1]
      [
        [
          [1]
        ]
      ]
    >

## broadcast_vectors/2

Broadcasts vectorized axes, ensuring they end up with the same final size.

The inner shape is unchanged for each tensor.
The order of the vectorized axes is determined by order of appearance in the input list.

## Options

  * `:align_ranks` - boolean that indicates whether the inner
    shapes should be aligned to the maximum rank of the inputs.
    That is, 1-sized leading dimensions are added so
    that all tensors have the same rank in the output.
    This only applies in case one of the inputs is vectorized.

## Examples

    iex> x = Nx.tensor([1, 2]) |> Nx.vectorize(:x)
    #Nx.Tensor<
      vectorized[x: 2]
      s32
      [1, 2]
    >
    iex> xy = Nx.tensor([[[5]], [[6]]]) |> Nx.vectorize(:y) |> Nx.vectorize(:x)
    #Nx.Tensor<
      vectorized[y: 2][x: 1]
      s32[1]
      [
        [
          [5]
        ],
        [
          [6]
        ]
      ]
    >
    iex> [broadcast_x, broadcast_xy] = Nx.broadcast_vectors([x, xy], align_ranks: true)
    iex> broadcast_x
    #Nx.Tensor<
      vectorized[x: 2][y: 2]
      s32[1]
      [
        [
          [1],
          [1]
        ],
        [
          [2],
          [2]
        ]
      ]
    >
    iex> broadcast_xy
    #Nx.Tensor<
      vectorized[x: 2][y: 2]
      s32[1]
      [
        [
          [5],
          [6]
        ],
        [
          [5],
          [6]
        ]
      ]
    >
    iex> [broadcast_xy, broadcast_x] = Nx.broadcast_vectors([xy, x])
    iex> broadcast_x
    #Nx.Tensor<
      vectorized[y: 2][x: 2]
      s32
      [
        [1, 2],
        [1, 2]
      ]
    >
    iex> broadcast_xy
    #Nx.Tensor<
      vectorized[y: 2][x: 2]
      s32[1]
      [
        [
          [5],
          [5]
        ],
        [
          [6],
          [6]
        ]
      ]
    >

## revectorize/3

Changes the disposition of the vectorized axes of a tensor or `Nx.Container`.

This function is basically a short-hand for:

    tensor
    |> Nx.devectorize(keep_names: false)
    |> Nx.reshape(vectorized_sizes ++ target_shape, names: target_names)
    |> Nx.vectorize(vectorized_names)

Accepts the `target_axes` keyword list where the total size must match the current total
size of the vectorized axes.

Between `target_axes` and the `:target_shape` option, there can be at most one `:auto` entry.

### Options

  * `:target_shape` - the (non-vectorized) output shape.
  * `:target_names` - the names for the output shape.

### Examples

    iex> t = Nx.iota({1}, vectorized_axes: [x: 2, y: 3, z: 4])
    iex> t2 = Nx.revectorize(t, x: 12, y: :auto)
    iex> t2.vectorized_axes
    [x: 12, y: 2]
    iex> t3 = Nx.revectorize(t, a: :auto)
    iex> t3.vectorized_axes
    [a: 24]

Also works on containers. Note that the revectorization happens on a per-entry basis.

    iex> t1  = Nx.iota({1}, vectorized_axes: [x: 2, y: 3])
    iex> t2 = Nx.iota({1}, vectorized_axes: [x: 2, y: 1])
    iex> {r1, r2} = Nx.revectorize({t1, t2}, a: :auto)
    iex> r1.vectorized_axes
    [a: 6]
    iex> r2.vectorized_axes
    [a: 2]

This function is useful for when you need to introduce a temporary custom axis to ease calculations.
The example below shows how to manipulate your vectorized tensor for that objective.

    iex> t = Nx.iota({2, 2, 2}) |> Nx.vectorize(x: 2, y: 2)
    #Nx.Tensor<
      vectorized[x: 2][y: 2]
      s32[2]
      [
        [
          [0, 1],
          [2, 3]
        ],
        [
          [4, 5],
          [6, 7]
        ]
      ]
    >
    iex> Nx.revectorize(t, temp: :auto, x: 2) # Note that if we don't pass `:target_shape`, `:auto` will only act upon the vectorized axes
    #Nx.Tensor<
      vectorized[temp: 2][x: 2]
      s32[2]
      [
        [
          [0, 1],
          [2, 3]
        ],
        [
          [4, 5],
          [6, 7]
        ]
      ]
    >
    iex> revec = Nx.revectorize(t, [temp: :auto, x: 2], target_shape: {})
    #Nx.Tensor<
      vectorized[temp: 4][x: 2]
      s32
      [
        [0, 1],
        [2, 3],
        [4, 5],
        [6, 7]
      ]
    >
    iex> Nx.revectorize(revec, [new_vec: 2], target_shape: {1, 4}, target_names: [:x, :last])
    #Nx.Tensor<
      vectorized[new_vec: 2]
      s32[x: 1][last: 4]
      [
        [
          [0, 1, 2, 3]
        ],
        [
          [4, 5, 6, 7]
        ]
      ]
    >

Note how in the last example the `:x` name could be reused in various positions
(both vectorized and non-vectorized), because `revectorize/2` ensures that the
names are rewritten at each call.

## add/2

Element-wise addition of two tensors.

If a number is given, it is converted to a tensor.

It will broadcast tensors whenever the dimensions do
not match and broadcasting is possible.

If you're using `Nx.Defn.defn/2`, you can use the `+` operator
in place of this function: `left + right`.

## Examples

### Adding scalars

    iex> Nx.add(1, 2)
    #Nx.Tensor<
      s32
      3
    >

    iex> Nx.add(1, 2.2)
    #Nx.Tensor<
      f32
      3.2
    >

### Adding a scalar to a tensor

    iex> Nx.add(Nx.tensor([1, 2, 3], names: [:data]), 1)
    #Nx.Tensor<
      s32[data: 3]
      [2, 3, 4]
    >

    iex> Nx.add(1, Nx.tensor([1, 2, 3], names: [:data]))
    #Nx.Tensor<
      s32[data: 3]
      [2, 3, 4]
    >

Given a float scalar converts the tensor to a float:

    iex> Nx.add(Nx.tensor([1, 2, 3], names: [:data]), 1.0)
    #Nx.Tensor<
      f32[data: 3]
      [2.0, 3.0, 4.0]
    >

    iex> Nx.add(Nx.tensor([1.0, 2.0, 3.0], names: [:data]), 1)
    #Nx.Tensor<
      f32[data: 3]
      [2.0, 3.0, 4.0]
    >

    iex> Nx.add(Nx.tensor([1.0, 2.0, 3.0], type: :f32, names: [:data]), 1)
    #Nx.Tensor<
      f32[data: 3]
      [2.0, 3.0, 4.0]
    >

Unsigned tensors become signed and double their size if a
negative number is given:

    iex> Nx.add(Nx.tensor([0, 1, 2], type: :u8, names: [:data]), -1)
    #Nx.Tensor<
      s16[data: 3]
      [-1, 0, 1]
    >

### Adding tensors of the same shape

    iex> left = Nx.tensor([[1, 2], [3, 4]], names: [:x, :y])
    iex> right = Nx.tensor([[10, 20], [30, 40]], names: [nil, :y])
    iex> Nx.add(left, right)
    #Nx.Tensor<
      s32[x: 2][y: 2]
      [
        [11, 22],
        [33, 44]
      ]
    >

### Adding tensors with broadcasting

    iex> left = Nx.tensor([[1], [2]], names: [nil, :y])
    iex> right = Nx.tensor([[10, 20]], names: [:x, nil])
    iex> Nx.add(left, right)
    #Nx.Tensor<
      s32[x: 2][y: 2]
      [
        [11, 21],
        [12, 22]
      ]
    >

    iex> left = Nx.tensor([[10, 20]], names: [:x, nil])
    iex> right = Nx.tensor([[1], [2]], names: [nil, :y])
    iex> Nx.add(left, right)
    #Nx.Tensor<
      s32[x: 2][y: 2]
      [
        [11, 21],
        [12, 22]
      ]
    >

    iex> left = Nx.tensor([[1], [2]], names: [:x, nil])
    iex> right = Nx.tensor([[10, 20], [30, 40]])
    iex> Nx.add(left, right)
    #Nx.Tensor<
      s32[x: 2][2]
      [
        [11, 21],
        [32, 42]
      ]
    >

    iex> left = Nx.tensor([[1, 2]])
    iex> right = Nx.tensor([[10, 20], [30, 40]])
    iex> Nx.add(left, right)
    #Nx.Tensor<
      s32[2][2]
      [
        [11, 22],
        [31, 42]
      ]
    >

## subtract/2

Element-wise subtraction of two tensors.

If a number is given, it is converted to a tensor.

It will broadcast tensors whenever the dimensions do
not match and broadcasting is possible.

If you're using `Nx.Defn.defn/2`, you can use the `-` operator
in place of this function: `left - right`.

## Examples

### Subtracting scalars

    iex> Nx.subtract(1, 2)
    #Nx.Tensor<
      s32
      -1
    >

### Subtracting tensors and scalars

    iex> Nx.subtract(Nx.tensor([1, 2, 3], names: [:data]), 1)
    #Nx.Tensor<
      s32[data: 3]
      [0, 1, 2]
    >

    iex> Nx.subtract(1, Nx.tensor([1.0, 2.0, 3.0], names: [:data]))
    #Nx.Tensor<
      f32[data: 3]
      [0.0, -1.0, -2.0]
    >

### Subtracting tensors

    iex> left = Nx.tensor([[1], [2]], names: [:x, :y])
    iex> right = Nx.tensor([[10, 20]], names: [:x, :y])
    iex> Nx.subtract(left, right)
    #Nx.Tensor<
      s32[x: 2][y: 2]
      [
        [-9, -19],
        [-8, -18]
      ]
    >

    iex> left = Nx.tensor([[1], [2]], type: :s8, names: [:x, nil])
    iex> right = Nx.tensor([[10, 20]], type: :s8, names: [nil, :y])
    iex> Nx.subtract(left, right)
    #Nx.Tensor<
      s8[x: 2][y: 2]
      [
        [-9, -19],
        [-8, -18]
      ]
    >

    iex> left = Nx.tensor([[1], [2]], type: :f32, names: [nil, :y])
    iex> right = Nx.tensor([[10, 20]], type: :f32, names: [:x, nil])
    iex> Nx.subtract(left, right)
    #Nx.Tensor<
      f32[x: 2][y: 2]
      [
        [-9.0, -19.0],
        [-8.0, -18.0]
      ]
    >

## multiply/2

Element-wise multiplication of two tensors.

If a number is given, it is converted to a tensor.

It will broadcast tensors whenever the dimensions do
not match and broadcasting is possible.

If you're using `Nx.Defn.defn/2`, you can use the `*` operator
operator in place of this function as `left * right`.

## Examples

### Multiplying scalars

    iex> Nx.multiply(1, 2)
    #Nx.Tensor<
      s32
      2
    >

### Multiplying tensors and scalars

    iex> Nx.multiply(Nx.tensor([1, 2, 3], names: [:data]), 1)
    #Nx.Tensor<
      s32[data: 3]
      [1, 2, 3]
    >

    iex> Nx.multiply(1, Nx.tensor([1.0, 2.0, 3.0], names: [:data]))
    #Nx.Tensor<
      f32[data: 3]
      [1.0, 2.0, 3.0]
    >

### Multiplying tensors

    iex> left = Nx.tensor([[1], [2]], names: [:x, :y])
    iex> right = Nx.tensor([[10, 20]], names: [:x, :y])
    iex> Nx.multiply(left, right)
    #Nx.Tensor<
      s32[x: 2][y: 2]
      [
        [10, 20],
        [20, 40]
      ]
    >

    iex> left = Nx.tensor([[1], [2]], type: :s8, names: [:x, nil])
    iex> right = Nx.tensor([[10, 20]], type: :s8, names: [nil, :y])
    iex> Nx.multiply(left, right)
    #Nx.Tensor<
      s8[x: 2][y: 2]
      [
        [10, 20],
        [20, 40]
      ]
    >

    iex> left = Nx.tensor([[1], [2]], type: :f32, names: [nil, :y])
    iex> right = Nx.tensor([[10, 20]], type: :f32, names: [:x, nil])
    iex> Nx.multiply(left, right)
    #Nx.Tensor<
      f32[x: 2][y: 2]
      [
        [10.0, 20.0],
        [20.0, 40.0]
      ]
    >

## pow/2

Element-wise power of two tensors.

If a number is given, it is converted to a tensor.

It will broadcast tensors whenever the dimensions do
not match and broadcasting is possible.

If both tensors are integers and the exponent is
negative, it will raise, but it may trigger undefined
behaviour on some compilers.

## Examples

### Power of scalars

    iex> Nx.pow(2, 4)
    #Nx.Tensor<
      s32
      16
    >

### Power of tensors and scalars

    iex> Nx.pow(Nx.tensor([1, 2, 3], names: [:data]), 2)
    #Nx.Tensor<
      s32[data: 3]
      [1, 4, 9]
    >

    iex> Nx.pow(2, Nx.tensor([1.0, 2.0, 3.0], names: [:data]))
    #Nx.Tensor<
      f32[data: 3]
      [2.0, 4.0, 8.0]
    >

### Power of tensors

    iex> Nx.pow(Nx.tensor([[2], [3]], names: [:x, nil]), Nx.tensor([[4, 5]], names: [nil, :y]))
    #Nx.Tensor<
      s32[x: 2][y: 2]
      [
        [16, 32],
        [81, 243]
      ]
    >

## remainder/2

Element-wise remainder of two tensors.

If a number is given, it is converted to a tensor.

It will broadcast tensors whenever the dimensions do
not match and broadcasting is possible.

If you're using `Nx.Defn.defn/2`, you can use the `rem/2` function
in place of this function: `rem(left, right)`.

## Examples

### Remainder of scalars

    iex> Nx.remainder(1, 2)
    #Nx.Tensor<
      s32
      1
    >

### Remainder of tensors and scalars

    iex> Nx.remainder(Nx.tensor([1, 2, 3], names: [:data]), 2)
    #Nx.Tensor<
      s32[data: 3]
      [1, 0, 1]
    >

    iex> Nx.remainder(2, Nx.tensor([1.0, 2.0, 3.0], names: [:data]))
    #Nx.Tensor<
      f32[data: 3]
      [0.0, 0.0, 2.0]
    >

### Remainder of tensors

    iex> left = Nx.tensor([[10], [20]], names: [:x, :y])
    iex> right = Nx.tensor([[3, 4]], names: [nil, :y])
    iex> Nx.remainder(left, right)
    #Nx.Tensor<
      s32[x: 2][y: 2]
      [
        [1, 2],
        [2, 0]
      ]
    >

### Remainder involving negative values

If given a negative value as the right operand, the operation
will return the negative image of the remainder.

For the example below, note that in modulo-10, adding 20 shouldn't
change the result, but in this case it does because the sign changes.

    iex> left = Nx.tensor(-11, type: :s8)
    iex> right = Nx.tensor(10, type: :u8)
    iex> Nx.remainder(left, right)
    #Nx.Tensor<
      s16
      -1
    >
    iex> Nx.remainder(Nx.add(left, Nx.tensor(20, type: :s8)), right)
    #Nx.Tensor<
      s16
      9
    >
    iex> positive_left = Nx.tensor(9, type: :u8)
    iex> Nx.remainder(positive_left, right)
    #Nx.Tensor<
      u8
      9
    >
    iex> Nx.remainder(Nx.add(positive_left, Nx.tensor(20, type: :u8)), right)
    #Nx.Tensor<
      u8
      9
    >

## divide/2

Element-wise division of two tensors.

If a number is given, it is converted to a tensor.

It always returns a float tensor. If any of the input
tensors are not float, they are converted to f32.
Division by zero raises, but it may trigger undefined
behaviour on some compilers.

It will broadcast tensors whenever the dimensions do
not match and broadcasting is possible.

If you're using `Nx.Defn.defn/2`, you can use the `/` operator
in place of this function: `left / right`.

## Examples

### Dividing scalars

    iex> Nx.divide(1, 2)
    #Nx.Tensor<
      f32
      0.5
    >

### Dividing tensors and scalars

    iex> Nx.divide(Nx.tensor([1, 2, 3], names: [:data]), 1)
    #Nx.Tensor<
      f32[data: 3]
      [1.0, 2.0, 3.0]
    >

    iex> Nx.divide(1, Nx.tensor([1.0, 2.0, 3.0], names: [:data]))
    #Nx.Tensor<
      f32[data: 3]
      [1.0, 0.5, 0.33333334]
    >

### Dividing tensors

    iex> left = Nx.tensor([[1], [2]], names: [:x, nil])
    iex> right = Nx.tensor([[10, 20]], names: [nil, :y])
    iex> Nx.divide(left, right)
    #Nx.Tensor<
      f32[x: 2][y: 2]
      [
        [0.1, 0.05],
        [0.2, 0.1]
      ]
    >

    iex> left = Nx.tensor([[1], [2]], type: :s8)
    iex> right = Nx.tensor([[10, 20]], type: :s8, names: [:x, :y])
    iex> Nx.divide(left, right)
    #Nx.Tensor<
      f32[x: 2][y: 2]
      [
        [0.1, 0.05],
        [0.2, 0.1]
      ]
    >

    iex> left = Nx.tensor([[1], [2]], type: :f32, names: [:x, nil])
    iex> right = Nx.tensor([[10, 20]], type: :f32, names: [nil, :y])
    iex> Nx.divide(left, right)
    #Nx.Tensor<
      f32[x: 2][y: 2]
      [
        [0.1, 0.05],
        [0.2, 0.1]
      ]
    >

## quotient/2

Element-wise integer division of two tensors.

If a number is given, it is converted to a tensor.

It always returns an integer tensor. Input tensors and
numbers must be integer types. Division by zero raises,
but it may trigger undefined behaviour on some compilers.

It will broadcast tensors whenever the dimensions do
not match and broadcasting is possible.

## Caveat for `grad`

The `grad` operation is not supported for `quotient/2`.
Since integer division is, by definition, a closed operation
for the set of integers and grad involves floating points,
`grad` is undefined.

If you need to support gradients, you might consider using
floor division, but beware of precision errors caused by
floating points:

    a |> Nx.divide(b) |> Nx.floor()

## Examples

### Integer dividing scalars

    iex> Nx.quotient(11, 2)
    #Nx.Tensor<
      s32
      5
    >

### Integer dividing tensors and scalars

    iex> Nx.quotient(Nx.tensor([2, 4, 5], names: [:data]), 2)
    #Nx.Tensor<
      s32[data: 3]
      [1, 2, 2]
    >

    iex> Nx.quotient(10, Nx.tensor([1, 2, 3], names: [:data]))
    #Nx.Tensor<
      s32[data: 3]
      [10, 5, 3]
    >

### Dividing tensors

    iex> left = Nx.tensor([[10, 20]], names: [nil, :y])
    iex> right = Nx.tensor([[1], [2]], names: [:x, nil])
    iex> Nx.quotient(left, right)
    #Nx.Tensor<
      s32[x: 2][y: 2]
      [
        [10, 20],
        [5, 10]
      ]
    >

    iex> left = Nx.tensor([[10, 20]], type: :s8, names: [:x, :y])
    iex> right = Nx.tensor([[1], [2]], type: :s8)
    iex> Nx.quotient(left, right)
    #Nx.Tensor<
      s8[x: 2][y: 2]
      [
        [10, 20],
        [5, 10]
      ]
    >

    iex> left = Nx.tensor([[10, 20]], type: :u8, names: [:x, :y])
    iex> right = Nx.tensor([[1], [2]], type: :u32)
    iex> Nx.quotient(left, right)
    #Nx.Tensor<
      u32[x: 2][y: 2]
      [
        [10, 20],
        [5, 10]
      ]
    >

## atan2/2

Element-wise arc tangent of two tensors.

If a number is given, it is converted to a tensor.

It always returns a float tensor. If any of the input
tensors are not float, they are converted to f32.

It will broadcast tensors whenever the dimensions do
not match and broadcasting is possible.

## Examples

### Arc tangent between scalars

    iex> Nx.atan2(1, 2)
    #Nx.Tensor<
      f32
      0.4636476
    >

### Arc tangent between tensors and scalars

    iex> Nx.atan2(Nx.tensor([1, 2, 3], names: [:data]), 1)
    #Nx.Tensor<
      f32[data: 3]
      [0.7853982, 1.1071488, 1.2490457]
    >

    iex> Nx.atan2(1, Nx.tensor([1.0, 2.0, 3.0], names: [:data]))
    #Nx.Tensor<
      f32[data: 3]
      [0.7853982, 0.4636476, 0.32175055]
    >

### Arc tangent between tensors

    iex> neg_and_pos_zero_columns = Nx.tensor([[-0.0], [0.0]], type: :f64)
    iex> neg_and_pos_zero_rows = Nx.tensor([-0.0, 0.0], type: :f64)
    iex> Nx.atan2(neg_and_pos_zero_columns, neg_and_pos_zero_rows)
    #Nx.Tensor<
      f64[2][2]
      [
        [-3.141592653589793, -0.0],
        [3.141592653589793, 0.0]
      ]
    >

## max/2

Element-wise maximum of two tensors.

If a number is given, it is converted to a tensor.

It will broadcast tensors whenever the dimensions do
not match and broadcasting is possible.

If you're using `Nx.Defn.defn/2`, you can use the `max/2` function
in place of this function: `max(left, right)`.

## Examples

### Max between scalars

    iex> Nx.max(1, 2)
    #Nx.Tensor<
      s32
      2
    >

### Max between tensors and scalars

    iex> Nx.max(Nx.tensor([1, 2, 3], names: [:data]), 1)
    #Nx.Tensor<
      s32[data: 3]
      [1, 2, 3]
    >

    iex> Nx.max(1, Nx.tensor([1.0, 2.0, 3.0], names: [:data]))
    #Nx.Tensor<
      f32[data: 3]
      [1.0, 2.0, 3.0]
    >

### Max between tensors

    iex> left = Nx.tensor([[1], [2]], names: [:x, :y])
    iex> right = Nx.tensor([[10, 20]])
    iex> Nx.max(left, right)
    #Nx.Tensor<
      s32[x: 2][y: 2]
      [
        [10, 20],
        [10, 20]
      ]
    >

    iex> left = Nx.tensor([[1], [2]], type: :s8, names: [:x, nil])
    iex> right = Nx.tensor([[10, 20]], type: :s8)
    iex> Nx.max(left, right)
    #Nx.Tensor<
      s8[x: 2][2]
      [
        [10, 20],
        [10, 20]
      ]
    >

    iex> left = Nx.tensor([[1], [2]], type: :f32, names: [:x, nil])
    iex> right = Nx.tensor([[10, 20]], type: :f32, names: [nil, :y])
    iex> Nx.max(left, right)
    #Nx.Tensor<
      f32[x: 2][y: 2]
      [
        [10.0, 20.0],
        [10.0, 20.0]
      ]
    >

## min/2

Element-wise minimum of two tensors.

If a number is given, it is converted to a tensor.

It will broadcast tensors whenever the dimensions do
not match and broadcasting is possible.

If you're using `Nx.Defn.defn/2`, you can use the `min/2` function
in place of this function: `min(left, right)`.

## Examples

### Min between scalars

    iex> Nx.min(1, 2)
    #Nx.Tensor<
      s32
      1
    >

### Min between tensors and scalars

    iex> Nx.min(Nx.tensor([1, 2, 3], names: [:data]), 1)
    #Nx.Tensor<
      s32[data: 3]
      [1, 1, 1]
    >

    iex> Nx.min(1, Nx.tensor([1.0, 2.0, 3.0], names: [:data]))
    #Nx.Tensor<
      f32[data: 3]
      [1.0, 1.0, 1.0]
    >

### Min between tensors

    iex> left = Nx.tensor([[1], [2]], names: [:x, nil])
    iex> right = Nx.tensor([[10, 20]])
    iex> Nx.min(left, right)
    #Nx.Tensor<
      s32[x: 2][2]
      [
        [1, 1],
        [2, 2]
      ]
    >

    iex> left = Nx.tensor([[1], [2]], type: :s8, names: [:x, :y])
    iex> right = Nx.tensor([[10, 20]], type: :s8)
    iex> Nx.min(left, right)
    #Nx.Tensor<
      s8[x: 2][y: 2]
      [
        [1, 1],
        [2, 2]
      ]
    >

    iex> left = Nx.tensor([[1], [2]], type: :f32, names: [:x, nil])
    iex> right = Nx.tensor([[10, 20]], type: :f32, names: [nil, :y])
    iex> Nx.min(left, right)
    #Nx.Tensor<
      f32[x: 2][y: 2]
      [
        [1.0, 1.0],
        [2.0, 2.0]
      ]
    >

## bitwise_and/2

Element-wise bitwise AND of two tensors.

Only integer tensors are supported. If a float or
complex tensor is given, an error is raised.

It will broadcast tensors whenever the dimensions do
not match and broadcasting is possible.

If you're using `Nx.Defn.defn/2`, you can use the `&&&` operator
in place of this function: `left &&& right`.

It does not support short-circuiting.

## Examples

### bitwise and between scalars

    iex> Nx.bitwise_and(1, 0)
    #Nx.Tensor<
      s32
      0
    >

### bitwise and between tensors and scalars

    iex> Nx.bitwise_and(Nx.tensor([0, 1, 2], names: [:data]), 1)
    #Nx.Tensor<
      s32[data: 3]
      [0, 1, 0]
    >

    iex> Nx.bitwise_and(Nx.tensor([0, -1, -2], names: [:data]), -1)
    #Nx.Tensor<
      s32[data: 3]
      [0, -1, -2]
    >

### bitwise and between tensors

    iex> Nx.bitwise_and(Nx.tensor([0, 0, 1, 1], names: [:data]), Nx.tensor([0, 1, 0, 1]))
    #Nx.Tensor<
      s32[data: 4]
      [0, 0, 0, 1]
    >

## Error cases

    iex> Nx.bitwise_and(Nx.tensor([0, 0, 1, 1]), 1.0)
    ** (ArgumentError) bitwise operators expect integer tensors as inputs and outputs an integer tensor, got: {:f, 32}

## bitwise_or/2

Element-wise bitwise OR of two tensors.

Only integer tensors are supported. If a float or
complex tensor is given, an error is raised.

It will broadcast tensors whenever the dimensions do
not match and broadcasting is possible.

If you're using `Nx.Defn.defn/2`, you can use the `|||` operator
in place of this function: `left ||| right`.

It does not support short-circuiting.

## Examples

### bitwise or between scalars

    iex> Nx.bitwise_or(1, 0)
    #Nx.Tensor<
      s32
      1
    >

### bitwise or between tensors and scalars

    iex> Nx.bitwise_or(Nx.tensor([0, 1, 2], names: [:data]), 1)
    #Nx.Tensor<
      s32[data: 3]
      [1, 1, 3]
    >

    iex> Nx.bitwise_or(Nx.tensor([0, -1, -2], names: [:data]), -1)
    #Nx.Tensor<
      s32[data: 3]
      [-1, -1, -1]
    >

### bitwise or between tensors

    iex> Nx.bitwise_or(Nx.tensor([0, 0, 1, 1], names: [:data]), Nx.tensor([0, 1, 0, 1], names: [:data]))
    #Nx.Tensor<
      s32[data: 4]
      [0, 1, 1, 1]
    >

## Error cases

    iex> Nx.bitwise_or(Nx.tensor([0, 0, 1, 1]), 1.0)
    ** (ArgumentError) bitwise operators expect integer tensors as inputs and outputs an integer tensor, got: {:f, 32}

## bitwise_xor/2

Element-wise bitwise XOR of two tensors.

Only integer tensors are supported. If a float or complex
tensor is given, an error is raised.

It will broadcast tensors whenever the dimensions do
not match and broadcasting is possible.

## Examples

### Bitwise xor between scalars

    iex> Nx.bitwise_xor(1, 0)
    #Nx.Tensor<
      s32
      1
    >

### Bitwise xor and between tensors and scalars

    iex> Nx.bitwise_xor(Nx.tensor([1, 2, 3], names: [:data]), 2)
    #Nx.Tensor<
      s32[data: 3]
      [3, 0, 1]
    >

    iex> Nx.bitwise_xor(Nx.tensor([-1, -2, -3], names: [:data]), 2)
    #Nx.Tensor<
      s32[data: 3]
      [-3, -4, -1]
    >

### Bitwise xor between tensors

    iex> Nx.bitwise_xor(Nx.tensor([0, 0, 1, 1]), Nx.tensor([0, 1, 0, 1], names: [:data]))
    #Nx.Tensor<
      s32[data: 4]
      [0, 1, 1, 0]
    >

## Error cases

    iex> Nx.bitwise_xor(Nx.tensor([0, 0, 1, 1]), 1.0)
    ** (ArgumentError) bitwise operators expect integer tensors as inputs and outputs an integer tensor, got: {:f, 32}

## left_shift/2

Element-wise left shift of two tensors.

Only integer tensors are supported. If a float or complex
tensor is given, an error is raised. If the right side
is negative, it will raise, but it may trigger undefined
behaviour on some compilers.

It will broadcast tensors whenever the dimensions do
not match and broadcasting is possible. If the number of
shifts are negative, Nx's default backend will raise,
but it may trigger undefined behaviour in other backends.

If you're using `Nx.Defn.defn/2`, you can use the `<<<` operator
in place of this function: `left <<< right`.

## Examples

### Left shift between scalars

    iex> Nx.left_shift(1, 0)
    #Nx.Tensor<
      s32
      1
    >

### Left shift between tensors and scalars

    iex> Nx.left_shift(Nx.tensor([1, 2, 3], names: [:data]), 2)
    #Nx.Tensor<
      s32[data: 3]
      [4, 8, 12]
    >

### Left shift between tensors

    iex> left = Nx.tensor([1, 1, -1, -1], names: [:data])
    iex> right = Nx.tensor([1, 2, 3, 4], names: [:data])
    iex> Nx.left_shift(left, right)
    #Nx.Tensor<
      s32[data: 4]
      [2, 4, -8, -16]
    >

## Error cases

    iex> Nx.left_shift(Nx.tensor([0, 0, 1, 1]), 1.0)
    ** (ArgumentError) bitwise operators expect integer tensors as inputs and outputs an integer tensor, got: {:f, 32}

## right_shift/2

Element-wise right shift of two tensors.

Only integer tensors are supported. If a float or complex
tensor is given, an error is raised. If the right side
is negative, it will raise, but it may trigger undefined
behaviour on some compilers.

It performs an arithmetic shift if the tensor is made of
signed integers, it performs a logical shift otherwise.
In other words, it preserves the sign for signed integers.

It will broadcast tensors whenever the dimensions do
not match and broadcasting is possible. If the number of
shifts are negative, Nx's default backend will raise,
but it may trigger undefined behaviour in other backends.

If you're using `Nx.Defn.defn/2`, you can use the `>>>` operator
in place of this function: `left >>> right`.

## Examples

### Right shift between scalars

    iex> Nx.right_shift(1, 0)
    #Nx.Tensor<
      s32
      1
    >

### Right shift between tensors and scalars

    iex> Nx.right_shift(Nx.tensor([2, 4, 8], names: [:data]), 2)
    #Nx.Tensor<
      s32[data: 3]
      [0, 1, 2]
    >

### Right shift between tensors

    iex> left = Nx.tensor([16, 32, -64, -128], names: [:data])
    iex> right = Nx.tensor([1, 2, 3, 4])
    iex> Nx.right_shift(left, right)
    #Nx.Tensor<
      s32[data: 4]
      [8, 8, -8, -8]
    >

## Error cases

    iex> Nx.right_shift(Nx.tensor([0, 0, 1, 1]), 1.0)
    ** (ArgumentError) bitwise operators expect integer tensors as inputs and outputs an integer tensor, got: {:f, 32}

## equal/2

Element-wise equality comparison of two tensors.

If a number is given, it is converted to a tensor.

It will broadcast tensors whenever the dimensions do
not match and broadcasting is possible.

If you're using `Nx.Defn.defn/2`, you can use the `==` operator
in place of this function: `left == right`.

## Examples

### Comparison of scalars

    iex> Nx.equal(1, 2)
    #Nx.Tensor<
      u8
      0
    >

### Comparison of tensors and scalars

    iex> Nx.equal(1, Nx.tensor([1, 2, 3], names: [:data]))
    #Nx.Tensor<
      u8[data: 3]
      [1, 0, 0]
    >

### Comparison of tensors

    iex> left = Nx.tensor([1, 2, 3], names: [:data])
    iex> right = Nx.tensor([1, 2, 5])
    iex> Nx.equal(left, right)
    #Nx.Tensor<
      u8[data: 3]
      [1, 1, 0]
    >

    iex> left = Nx.tensor([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]], names: [:x, nil])
    iex> right = Nx.tensor([1, 2, 3])
    iex> Nx.equal(left, right)
    #Nx.Tensor<
      u8[x: 2][3]
      [
        [1, 1, 1],
        [0, 0, 0]
      ]
    >

## logical_and/2

Element-wise logical and of two tensors.

Zero is considered false, any other number is considered
true.

It will broadcast tensors whenever the dimensions do
not match and broadcasting is possible.

If you're using `Nx.Defn.defn/2`, you can use the `and` operator
in place of this function: `left and right`.

## Examples

    iex> Nx.logical_and(1, Nx.tensor([-1, 0, 1], names: [:data]))
    #Nx.Tensor<
      u8[data: 3]
      [1, 0, 1]
    >

    iex> left = Nx.tensor([-1, 0, 1], names: [:data])
    iex> right = Nx.tensor([[-1], [0], [1]])
    iex> Nx.logical_and(left, right)
    #Nx.Tensor<
      u8[3][data: 3]
      [
        [1, 0, 1],
        [0, 0, 0],
        [1, 0, 1]
      ]
    >

    iex> left = Nx.tensor([-1.0, 0.0, 1.0], names: [:data])
    iex> right = Nx.tensor([[-1], [0], [1]])
    iex> Nx.logical_and(left, right)
    #Nx.Tensor<
      u8[3][data: 3]
      [
        [1, 0, 1],
        [0, 0, 0],
        [1, 0, 1]
      ]
    >

## logical_or/2

Element-wise logical or of two tensors.

Zero is considered false, any other number is considered
true.

It will broadcast tensors whenever the dimensions do
not match and broadcasting is possible.

If you're using `Nx.Defn.defn/2`, you can use the `or` operator
in place of this function: `left or right`.

## Examples

    iex> Nx.logical_or(0, Nx.tensor([-1, 0, 1], names: [:data]))
    #Nx.Tensor<
      u8[data: 3]
      [1, 0, 1]
    >

    iex> left = Nx.tensor([-1, 0, 1], names: [:data])
    iex> right = Nx.tensor([[-1], [0], [1]])
    iex> Nx.logical_or(left, right)
    #Nx.Tensor<
      u8[3][data: 3]
      [
        [1, 1, 1],
        [1, 0, 1],
        [1, 1, 1]
      ]
    >

    iex> left = Nx.tensor([-1.0, 0.0, 1.0], names: [:data])
    iex> right = Nx.tensor([[-1], [0], [1]])
    iex> Nx.logical_or(left, right)
    #Nx.Tensor<
      u8[3][data: 3]
      [
        [1, 1, 1],
        [1, 0, 1],
        [1, 1, 1]
      ]
    >

## logical_xor/2

Element-wise logical xor of two tensors.

Zero is considered false, any other number is considered
true.

It will broadcast tensors whenever the dimensions do
not match and broadcasting is possible.

## Examples

    iex> Nx.logical_xor(0, Nx.tensor([-1, 0, 1], names: [:data]))
    #Nx.Tensor<
      u8[data: 3]
      [1, 0, 1]
    >

    iex> left = Nx.tensor([-1, 0, 1], names: [:data])
    iex> right = Nx.tensor([[-1], [0], [1]])
    iex> Nx.logical_xor(left, right)
    #Nx.Tensor<
      u8[3][data: 3]
      [
        [0, 1, 0],
        [1, 0, 1],
        [0, 1, 0]
      ]
    >

    iex> left = Nx.tensor([-1.0, 0.0, 1.0], names: [:data])
    iex> right = Nx.tensor([[-1], [0], [1]])
    iex> Nx.logical_xor(left, right)
    #Nx.Tensor<
      u8[3][data: 3]
      [
        [0, 1, 0],
        [1, 0, 1],
        [0, 1, 0]
      ]
    >

## logical_not/1

Element-wise logical not a tensor.

Zero is considered false, any other number is considered
true.

If you're using `Nx.Defn.defn/2`, you can use the `not` operator
in place of this function: `not tensor`.

## Examples

    iex> Nx.logical_not(Nx.tensor([-1, 0, 1], names: [:data]))
    #Nx.Tensor<
      u8[data: 3]
      [0, 1, 0]
    >

    iex> Nx.logical_not(Nx.tensor([-1.0, 0.0, 1.0], names: [:data]))
    #Nx.Tensor<
      u8[data: 3]
      [0, 1, 0]
    >

## block/4

Executes an extensible computation block.

`struct` identifies the block and carries static configuration. `args` is a
list of runtime inputs and `output` is the output template. The default
implementation `fun` receives the struct first and then each argument in
order (`apply(fun, [struct | args])`).

The backend’s `c:Nx.Backend.block/4` receives `struct`, `output`, `args`, and `fun`, and
should either run a native implementation or invoke the default as
`apply(fun, [struct | args])`.

## not_equal/2

Element-wise not-equal comparison of two tensors.

If a number is given, it is converted to a tensor.

It will broadcast tensors whenever the dimensions do
not match and broadcasting is possible.

If you're using `Nx.Defn.defn/2`, you can use the `!=` operator
in place of this function: `left != right`.

## Examples

### Comparison of scalars

    iex> Nx.not_equal(1, 2)
    #Nx.Tensor<
      u8
      1
    >

### Comparison of tensor and scalar

    iex> Nx.not_equal(Nx.tensor([1, 2, 3], names: [:data]), Nx.tensor(1))
    #Nx.Tensor<
      u8[data: 3]
      [0, 1, 1]
    >

### Comparison of tensors

    iex> left = Nx.tensor([1, 1, 2])
    iex> right = Nx.tensor([1, 2, 3], names: [:data])
    iex> Nx.not_equal(left, right)
    #Nx.Tensor<
      u8[data: 3]
      [0, 1, 1]
    >

    iex> left = Nx.tensor([[1, 4, 2], [4, 5, 6]], names: [:x, :y])
    iex> right = Nx.tensor([[1, 3, 2], [4, 2, 1]], names: [:x, :y])
    iex> Nx.not_equal(left, right)
    #Nx.Tensor<
      u8[x: 2][y: 3]
      [
        [0, 1, 0],
        [0, 1, 1]
      ]
    >

## greater/2

Element-wise greater than comparison of two tensors.

If a number is given, it is converted to a tensor.

It will broadcast tensors whenever the dimensions do
not match and broadcasting is possible.

If you're using `Nx.Defn.defn/2`, you can use the `>` operator
in place of this function: `left > right`.

## Examples

### Comparison of scalars

    iex> Nx.greater(1, 2)
    #Nx.Tensor<
      u8
      0
    >

### Comparison of tensors and scalars

    iex> Nx.greater(1, Nx.tensor([1, 2, 3], names: [:data]))
    #Nx.Tensor<
      u8[data: 3]
      [0, 0, 0]
    >

### Comparison of tensors

    iex> left = Nx.tensor([1, 2, 3], names: [:data])
    iex> right = Nx.tensor([1, 2, 2])
    iex> Nx.greater(left, right)
    #Nx.Tensor<
      u8[data: 3]
      [0, 0, 1]
    >

    iex> left = Nx.tensor([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]], names: [:x, :y])
    iex> right = Nx.tensor([1, 2, 3])
    iex> Nx.greater(left, right)
    #Nx.Tensor<
      u8[x: 2][y: 3]
      [
        [0, 0, 0],
        [1, 1, 1]
      ]
    >

## less/2

Element-wise less than comparison of two tensors.

If a number is given, it is converted to a tensor.

It will broadcast tensors whenever the dimensions do
not match and broadcasting is possible.

If you're using `Nx.Defn.defn/2`, you can use the `<` operator
in place of this function: `left < right`.

## Examples

### Comparison of scalars

    iex> Nx.less(1, 2)
    #Nx.Tensor<
      u8
      1
    >

### Comparison of tensors and scalars

    iex> Nx.less(1, Nx.tensor([1, 2, 3], names: [:data]))
    #Nx.Tensor<
      u8[data: 3]
      [0, 1, 1]
    >

### Comparison of tensors

    iex> Nx.less(Nx.tensor([1, 2, 1]), Nx.tensor([1, 2, 2], names: [:data]))
    #Nx.Tensor<
      u8[data: 3]
      [0, 0, 1]
    >

    iex> Nx.less(Nx.tensor([[1.0, 2.0, 3.0], [4.0, 2.0, 1.0]], names: [:x, :y]), Nx.tensor([1, 2, 3]))
    #Nx.Tensor<
      u8[x: 2][y: 3]
      [
        [0, 0, 0],
        [0, 0, 1]
      ]
    >

## greater_equal/2

Element-wise greater than or equal comparison of two tensors.

If a number is given, it is converted to a tensor.

It will broadcast tensors whenever the dimensions do
not match and broadcasting is possible.

If you're using `Nx.Defn.defn/2`, you can use the `>=` operator
in place of this function: `left >= right`.

## Examples

### Comparison of scalars

    iex> Nx.greater_equal(1, 2)
    #Nx.Tensor<
      u8
      0
    >

### Comparison of tensors and scalars

    iex> Nx.greater_equal(1, Nx.tensor([1, 2, 3], names: [:data]))
    #Nx.Tensor<
      u8[data: 3]
      [1, 0, 0]
    >

### Comparison of tensors

    iex> left = Nx.tensor([1, 2, 3], names: [:data])
    iex> right = Nx.tensor([1, 2, 2])
    iex> Nx.greater_equal(left, right)
    #Nx.Tensor<
      u8[data: 3]
      [1, 1, 1]
    >

    iex> left = Nx.tensor([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]], names: [:x, :y])
    iex> right = Nx.tensor([1, 2, 3])
    iex> Nx.greater_equal(left, right)
    #Nx.Tensor<
      u8[x: 2][y: 3]
      [
        [1, 1, 1],
        [1, 1, 1]
      ]
    >

## less_equal/2

Element-wise less than or equal comparison of two tensors.

If a number is given, it is converted to a tensor.

It will broadcast tensors whenever the dimensions do
not match and broadcasting is possible.

If you're using `Nx.Defn.defn/2`, you can use the `<=` operator
in place of this function: `left <= right`.

## Examples

### Comparison of scalars

    iex> Nx.less_equal(1, 2)
    #Nx.Tensor<
      u8
      1
    >

### Comparison of tensors and scalars

    iex> Nx.less_equal(1, Nx.tensor([1, 2, 3], names: [:data]))
    #Nx.Tensor<
      u8[data: 3]
      [1, 1, 1]
    >

### Comparison of tensors

    iex> left = Nx.tensor([1, 2, 3], names: [:data])
    iex> right = Nx.tensor([1, 2, 2])
    iex> Nx.less_equal(left, right)
    #Nx.Tensor<
      u8[data: 3]
      [1, 1, 0]
    >

    iex> left = Nx.tensor([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]])
    iex> right = Nx.tensor([1, 2, 3], names: [:y])
    iex> Nx.less_equal(left, right)
    #Nx.Tensor<
      u8[2][y: 3]
      [
        [1, 1, 1],
        [0, 0, 0]
      ]
    >

## select/3

Constructs a tensor from two tensors, based on a predicate.

The resulting tensor is built by evaluating each element of
`pred` and returning either the corresponding element from
`on_true` or `on_false`.

`pred` must either be `1` or `0` or a tensor of predicates
with a shape that matches the largest shape between `s1` or `s2`.

If the shape of `on_true` or `on_false` do not match the shape of
`pred`, attempts to broadcast both so they match the shape of `pred`.

## Examples

When the first argument is a scalar:

    iex> Nx.select(1, Nx.tensor([1, 2, 3], names: [:x]), Nx.tensor([4, 5, 6], names: [:x]))
    #Nx.Tensor<
      s32[x: 3]
      [1, 2, 3]
    >

    iex> Nx.select(0, Nx.tensor([1, 2, 3], names: [:y]), Nx.tensor([4, 5, 6], names: [:y]))
    #Nx.Tensor<
      s32[y: 3]
      [4, 5, 6]
    >

    iex> Nx.select(0, Nx.tensor([[1, 2]], names: [:x, :y]), Nx.tensor([[3], [4]], names: [:x, :y]))
    #Nx.Tensor<
      s32[x: 2][y: 2]
      [
        [3, 3],
        [4, 4]
      ]
    >

When the first argument is a tensor:

    iex> Nx.select(Nx.tensor([0, 1, 0], names: [:x]), Nx.tensor([1, 2, 3], names: [:y]), Nx.tensor([4, 5, 6], names: [:z]))
    #Nx.Tensor<
      s32[x: 3]
      [4, 2, 6]
    >

    iex> x = Nx.tensor([2, 4, 6], names: [:x])
    iex> y = Nx.tensor([3, 2, 1])
    iex> Nx.select(Nx.greater(x, y), Nx.tensor([2, 4, 6], names: [:i]), Nx.tensor([1, 3, 5], names: [:j]))
    #Nx.Tensor<
      s32[x: 3]
      [1, 4, 6]
    >

    iex> x = Nx.tensor([2, 4, 6, 8, 10], names: [:x])
    iex> y = Nx.tensor([1, 6, 2, 11, 2], names: [:x])
    iex> Nx.select(Nx.greater(x, y), Nx.tensor(2), Nx.tensor([1, 3, 5, 7, 9], names: [:x]))
    #Nx.Tensor<
      s32[x: 5]
      [2, 3, 2, 7, 2]
    >

If the tensor has other values, any non-zero value is considered true:

    iex> Nx.select(Nx.tensor([0, 1, 2], type: :u8), Nx.tensor([0, 0, 0]), Nx.tensor([1, 1, 1]))
    #Nx.Tensor<
      s32[3]
      [1, 0, 0]
    >

    iex> Nx.select(Nx.tensor([0, 1, 0]), Nx.tensor([1, 1, 1]), Nx.tensor([2.0, 2.0, 2.0]))
    #Nx.Tensor<
      f32[3]
      [2.0, 1.0, 2.0]
    >

## Vectorized tensors

Vectorized and non-vectorized tensors can be mixed-and-matched on all three inputs.

    iex> pred = Nx.tensor([[0, 1, 0], [1, 1, 0]]) |> Nx.vectorize(:x)
    iex> on_true = 1
    iex> on_false = Nx.tensor([2, 3]) |> Nx.vectorize(:y)
    iex> Nx.select(pred, on_true, on_false)
    #Nx.Tensor<
      vectorized[x: 2][y: 2]
      s32[3]
      [
        [
          [2, 1, 2],
          [3, 1, 3]
        ],
        [
          [1, 1, 2],
          [1, 1, 3]
        ]
      ]
    >

  In the next example, notice that even though the `pred` input
  is scalar, because we're dealing with vectorized inputs, some
  broadcasting still occurs.

    iex> pred = 1
    iex> on_true = Nx.tensor([1, 2, 3]) |> Nx.vectorize(:x)
    iex> on_false = Nx.tensor([4, 5]) |> Nx.vectorize(:y)
    iex> Nx.select(pred, on_true, on_false)
    #Nx.Tensor<
      vectorized[x: 3][y: 2]
      s32
      [
        [1, 1],
        [2, 2],
        [3, 3]
      ]
    >

Finally, broadcasting will also occur if more than one input share
the same vectorized axes, but one of them presents size 1

    iex> pred = Nx.tensor([1, 0, 0]) |> Nx.vectorize(:x)
    iex> on_true = Nx.tensor([[2]]) |> Nx.vectorize(:x) |> Nx.vectorize(:y)
    iex> on_false = Nx.tensor([3, 4]) |> Nx.vectorize(:y)
    iex> Nx.select(pred, on_true, on_false)
    #Nx.Tensor<
      vectorized[x: 3][y: 2]
      s32
      [
        [2, 2],
        [3, 4],
        [3, 4]
      ]
    >

## window_scatter_max/5

Performs a `window_reduce` to select the maximum index in each
window of the input tensor according to and scatters source tensor
to corresponding maximum indices in the output tensor.

Output tensor is initialized as a full tensor with values
`init_value`. If indices overlap, adds overlapping source values.
The shape of the source tensor must match the valid windows in the
input tensor. This means the shape of the source tensor must match
the shape of the input tensor after a `window_reduce` op with padding
`padding` and strides `strides`.

This function is the gradient of `window_max`.

## Examples

    iex> t = Nx.tensor([
    ...>   [7, 2, 5, 3, 10, 2],
    ...>   [3, 8, 9, 3, 4, 2],
    ...>   [1, 5, 7, 5, 6, 1],
    ...>   [0, 6, 2, 7, 2, 8]
    ...> ])
    iex> opts = [strides: [2, 3], padding: :valid]
    iex> Nx.window_scatter_max(t, Nx.tensor([[2, 6], [3, 1]]), 0, {2, 3}, opts)
    #Nx.Tensor<
      s32[4][6]
      [
        [0, 0, 0, 0, 6, 0],
        [0, 0, 2, 0, 0, 0],
        [0, 0, 3, 0, 0, 0],
        [0, 0, 0, 0, 0, 1]
      ]
    >

    iex> t = Nx.tensor([
    ...>   [7, 2, 5, 3, 8],
    ...>   [3, 8, 9, 3, 4],
    ...>   [1, 5, 7, 5, 6],
    ...>   [0, 6, 2, 10, 2]
    ...> ])
    iex> opts = [strides: [2, 2], padding: :valid]
    iex> Nx.window_scatter_max(t, Nx.tensor([[2, 6], [3, 1]]), 0, {2, 3}, opts)
    #Nx.Tensor<
      s32[4][5]
      [
        [0, 0, 0, 0, 0],
        [0, 0, 8, 0, 0],
        [0, 0, 3, 0, 0],
        [0, 0, 0, 1, 0]
      ]
    >

## Vectorized tensors

The source and target tensors can be vectorized, and will be broadcasted
through `broadcast_vectors/1` for the result calculation. `init_value`
must not be vectorized.

    iex> t = Nx.tensor([
    ...>   [
    ...>     [7, 2, 5, 3],
    ...>     [3, 8, 9, 3]
    ...>   ],
    ...>   [
    ...>     [1, 5, 7, 5],
    ...>     [0, 6, 2, 8]
    ...>   ]
    ...> ]) |> Nx.vectorize(:x)
    iex> opts = [strides: [1, 2], padding: :valid]
    iex> source = Nx.tensor([[[2, 6]], [[3, 1]]]) |> Nx.vectorize(:y)
    iex> Nx.window_scatter_max(t, source, 0, {2, 2}, opts)
    #Nx.Tensor<
      vectorized[x: 2][y: 2]
      s32[2][4]
      [
        [
          [
            [0, 0, 0, 0],
            [0, 2, 6, 0]
          ],
          [
            [0, 0, 0, 0],
            [0, 3, 1, 0]
          ]
        ],
        [
          [
            [0, 0, 0, 0],
            [0, 2, 0, 6]
          ],
          [
            [0, 0, 0, 0],
            [0, 3, 0, 1]
          ]
        ]
      ]
    >

## window_scatter_min/5

Performs a `window_reduce` to select the minimum index in each
window of the input tensor according to and scatters source tensor
to corresponding minimum indices in the output tensor.

Output tensor is initialized as a full tensor with values
`init_value`. If indices overlap, adds overlapping source values.
The shape of the source tensor must match the valid windows in the
input tensor. This means the shape of the source tensor must match
the shape of the input tensor after a `window_reduce` op with padding
`padding` and strides `strides`.

This function is the gradient of `window_min`.

## Examples

    iex> t = Nx.tensor([
    ...>   [7, 2, 5, 3, 10, 2],
    ...>   [3, 8, 9, 3, 4, 2],
    ...>   [1, 5, 7, 5, 6, 1],
    ...>   [0, 6, 2, 7, 2, 8]
    ...> ])
    iex> opts = [strides: [2, 3], padding: :valid]
    iex> Nx.window_scatter_min(t, Nx.tensor([[2, 6], [3, 1]]), 0, {2, 3}, opts)
    #Nx.Tensor<
      s32[4][6]
      [
        [0, 2, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 6],
        [0, 0, 0, 0, 0, 1],
        [3, 0, 0, 0, 0, 0]
      ]
    >

    iex> t = Nx.tensor([
    ...>   [7, 2, 5, 3, 8],
    ...>   [3, 8, 9, 3, 4],
    ...>   [1, 5, 7, 5, 6],
    ...>   [0, 6, 2, 10, 2]
    ...> ])
    iex> opts = [strides: [2, 2], padding: :valid]
    iex> Nx.window_scatter_min(t, Nx.tensor([[2, 6], [3, 1]]), 0, {2, 3}, opts)
    #Nx.Tensor<
      s32[4][5]
      [
        [0, 2, 0, 0, 0],
        [0, 0, 0, 6, 0],
        [0, 0, 0, 0, 0],
        [3, 0, 0, 0, 1]
      ]
    >

## Vectorized tensors

The source and target tensors can be vectorized, and will be broadcasted
through `broadcast_vectors/1` for the result calculation. `init_value`
must not be vectorized.

    iex> t = Nx.tensor([
    ...>   [
    ...>     [7, 2, 5, 1],
    ...>     [3, 8, 9, 3]
    ...>   ],
    ...>   [
    ...>     [1, 5, 7, 5],
    ...>     [0, 6, 2, 8]
    ...>   ]
    ...> ]) |> Nx.vectorize(:x)
    iex> opts = [strides: [1, 2], padding: :valid]
    iex> source = Nx.tensor([[[2, 6]], [[3, 1]]]) |> Nx.vectorize(:y)
    iex> Nx.window_scatter_min(t, source, 0, {2, 2}, opts)
    #Nx.Tensor<
      vectorized[x: 2][y: 2]
      s32[2][4]
      [
        [
          [
            [0, 2, 0, 6],
            [0, 0, 0, 0]
          ],
          [
            [0, 3, 0, 1],
            [0, 0, 0, 0]
          ]
        ],
        [
          [
            [0, 0, 0, 0],
            [2, 0, 6, 0]
          ],
          [
            [0, 0, 0, 0],
            [3, 0, 1, 0]
          ]
        ]
      ]
    >

## indexed_add/4

Performs an indexed `add` operation on the `target` tensor,
adding the `updates` into the corresponding `indices` positions.

This operation is the grad for `gather/2` and gather-like operations such as
`take/3` and `take_along_axis/3`.

`indices` must be a fully qualified tensor of shape `{n, Nx.rank(target)}`, with `n`
being an arbitrary number of indices, while `updates` must have a compatible `{n}` shape.

See also: `indexed_add/3`, `gather/2`, `take/3`, `take_along_axis/3`

## Options

  * `:axes` - controls which dimensions the indexes apply to.
    It must be a sorted list of axes and be of the same size
    as the second (last) dimension of the indexes tensor.
    It defaults to the leading axes of the tensor.

## Examples

### Adding a single entry as a scalar

As a shorthand notation, rank-1 indices can be used for updating a single entry:

      iex> Nx.indexed_add(Nx.tensor([[1], [2]]), Nx.tensor([1, 0]), 8)
      #Nx.Tensor<
        s32[2][1]
        [
          [1],
          [10]
        ]
      >

### Adding multiple scalar entries

    iex> t = Nx.iota({1, 2, 3})
    #Nx.Tensor<
      s32[1][2][3]
      [
        [
          [0, 1, 2],
          [3, 4, 5]
        ]
      ]
    >
    iex> indices = Nx.tensor([[0, 0, 0], [0, 1, 1], [0, 0, 0], [0, 0, 2], [0, 1, 2]])
    iex> updates = Nx.tensor([1, 3, 1, -2, 5])
    iex> Nx.indexed_add(t, indices, updates)
    #Nx.Tensor<
      s32[1][2][3]
      [
        [
          [2, 1, 0],
          [3, 7, 10]
        ]
      ]
    >

### Type promotions

Type promotions should happen automatically, with the resulting type being the combination
of the `target` type and the `updates` type.

    iex> Nx.indexed_add(Nx.tensor([1.0]), Nx.tensor([[0], [0]]), Nx.tensor([1, 1]))
    #Nx.Tensor<
      f32[1]
      [3.0]
    >

    iex> Nx.indexed_add(Nx.tensor([1]), Nx.tensor([[0], [0]]), Nx.tensor([1.0, 1.0]))
    #Nx.Tensor<
      f32[1]
      [3.0]
    >

    iex> Nx.indexed_add(Nx.tensor([1], type: :s32), Nx.tensor([[0], [0]]), Nx.tensor([1, 1], type: :s64))
    #Nx.Tensor<
      s64[1]
      [3]
    >

## Vectorized tensors

All of the inputs can be vectorized. The function will broadcast along the vectorized axes
before calculating the results.

    iex> x = Nx.tensor([[0, 10], [10, 20]]) |> Nx.vectorize(:x)
    iex> idx = Nx.tensor([[[0], [0]], [[0], [1]], [[1], [1]]]) |> Nx.vectorize(:y)
    iex> Nx.indexed_add(x, idx, Nx.tensor([1, 1]))
    #Nx.Tensor<
      vectorized[x: 2][y: 3]
      s32[2]
      [
        [
          [2, 10],
          [1, 11],
          [0, 12]
        ],
        [
          [12, 20],
          [11, 21],
          [10, 22]
        ]
      ]
    >

## Error cases

    iex> Nx.indexed_add(Nx.tensor([[1], [2]]), Nx.tensor([[[1, 2, 3]]]), Nx.tensor([0]))
    ** (ArgumentError) indices must be a rank 1 or 2 tensor, got: 3

    iex> Nx.indexed_add(Nx.tensor([[1], [2]]), Nx.tensor([[1, 2]]), Nx.tensor([0, 1]))
    ** (ArgumentError) expected the leading axis of indices ({1, 2}) and leading axis of updates ({2}) to match

    iex> Nx.indexed_add(Nx.tensor([[1, 2, 3]]), Nx.tensor([[0]]), Nx.tensor([[1, 2, 3, 4, 5]]))
    ** (ArgumentError) axis (1) of updates ({1, 5}) must be less than or equal to the axis (1) of {1, 3})

## indexed_put/4

Puts individual values from `updates` into the given tensor at the corresponding `indices`.

`indices` must be a fully qualified tensor of shape `{n, i}`, with `n` being an arbitrary
number of indices, while `updates` must have a compatible `{n, ...j}` shape, such that
`i + j = rank(tensor)`.

In case of repeating indices, the result is non-deterministic, since the operation happens
in parallel when running on devices such as the GPU.

See also: `indexed_add/3`, `put_slice/3`.

## Options

  * `:axes` - controls which dimensions the indexes apply to.
    It must be a sorted list of axes and be of the same size
    as the second (last) dimension of the indexes tensor.
    It defaults to the leading axes of the tensor.

## Examples

### Storing a single entry as a scalar

As a shorthand notation, rank-1 indices can be used for updating a single entry:

    iex> Nx.indexed_put(Nx.tensor([[1], [2]]), Nx.tensor([1, 0]), 10)
    #Nx.Tensor<
      s32[2][1]
      [
        [1],
        [10]
      ]
    >

### Storing multiple scalar entries scalars

    iex> Nx.indexed_put(Nx.tensor([0, 0, 0]), Nx.tensor([[1], [2]]), Nx.tensor([2, 4]))
    #Nx.Tensor<
      s32[3]
      [0, 2, 4]
    >

    iex> Nx.indexed_put(Nx.tensor([0, 0, 0]), Nx.tensor([[1], [2]]), Nx.tensor([3, 4]))
    #Nx.Tensor<
      s32[3]
      [0, 3, 4]
    >

    iex> t = Nx.iota({1, 2, 3})
    #Nx.Tensor<
      s32[1][2][3]
      [
        [
          [0, 1, 2],
          [3, 4, 5]
        ]
      ]
    >
    iex> indices = Nx.tensor([[0, 0, 0], [0, 1, 1], [0, 0, 2]])
    iex> updates = Nx.tensor([1, 3, -2])
    iex> Nx.indexed_put(t, indices, updates)
    #Nx.Tensor<
      s32[1][2][3]
      [
        [
          [1, 1, -2],
          [3, 3, 5]
        ]
      ]
    >

### Storing non-scalars on a given dimension

      iex> t = Nx.iota({1, 3, 2})
      #Nx.Tensor<
        s32[1][3][2]
        [
          [
            [0, 1],
            [2, 3],
            [4, 5]
          ]
        ]
      >
      iex> indices = Nx.tensor([[0, 0], [0, 2]])
      iex> updates = Nx.tensor([[0, 10], [40, 50]])
      iex> Nx.indexed_put(t, indices, updates)
      #Nx.Tensor<
        s32[1][3][2]
        [
          [
            [0, 10],
            [2, 3],
            [40, 50]
          ]
        ]
      >

The `:axes` option controls which dimensions the indexes apply to.
It must be a sorted list of axes. All non-listed axes are taken as
the update dimensions:

    iex> t = Nx.iota({1, 2, 3})
    #Nx.Tensor<
      s32[1][2][3]
      [
        [
          [0, 1, 2],
          [3, 4, 5]
        ]
      ]
    >
    iex> indices = Nx.tensor([[0, 0], [0, 2]])
    iex> updates = Nx.tensor([[0, 30], [20, 50]])
    iex> Nx.indexed_put(t, indices, updates, axes: [0, 2])
    #Nx.Tensor<
      s32[1][2][3]
      [
        [
          [0, 1, 20],
          [30, 4, 50]
        ]
      ]
    >

### Type promotions

Type promotions should happen automatically, with the resulting type being the combination
of the `target` type and the `updates` type.

    iex> Nx.indexed_put(Nx.tensor([1.0]), Nx.tensor([[0]]), Nx.tensor([3]))
    #Nx.Tensor<
      f32[1]
      [3.0]
    >

    iex> Nx.indexed_put(Nx.tensor([1]), Nx.tensor([[0]]), Nx.tensor([3.0]))
    #Nx.Tensor<
      f32[1]
      [3.0]
    >

    iex> Nx.indexed_put(Nx.tensor([1], type: :s32), Nx.tensor([[0]]), Nx.tensor([3], type: :s64))
    #Nx.Tensor<
      s64[1]
      [3]
    >

## Vectorized tensors

All of the inputs can be vectorized. The function will broadcast along the vectorized axes
before calculating the results.

    iex> x = Nx.tensor([[0, 10], [10, 20]]) |> Nx.vectorize(:x)
    iex> idx = Nx.tensor([[[0], [0]], [[0], [1]], [[1], [1]]]) |> Nx.vectorize(:y)
    iex> Nx.indexed_put(x, idx, Nx.tensor([1, 1]))
    #Nx.Tensor<
      vectorized[x: 2][y: 3]
      s32[2]
      [
        [
          [1, 10],
          [1, 1],
          [0, 1]
        ],
        [
          [1, 20],
          [1, 1],
          [10, 1]
        ]
      ]
    >

## Error cases

    iex> Nx.indexed_put(Nx.tensor([[1], [2]]), Nx.tensor([[[1, 2, 3]]]), Nx.tensor([0]))
    ** (ArgumentError) indices must be a rank 1 or 2 tensor, got: 3

    iex> Nx.indexed_put(Nx.tensor([[1], [2]]), Nx.tensor([[1, 2]]), Nx.tensor([0, 1]))
    ** (ArgumentError) expected the leading axis of indices ({1, 2}) and leading axis of updates ({2}) to match

    iex> Nx.indexed_put(Nx.iota({1, 2, 3}), Nx.tensor([[0, 1, 2]]), 10, axes: [1, 0, 2])
    ** (ArgumentError) :axes must be an ordered list

## is_nan/1

Determines if each element in `tensor` is a `NaN`.

For complex tensors, if either of the components is `NaN`,
the entry is deemed `NaN` as well.

## Examples

    iex> Nx.is_nan(Nx.tensor([:nan, 1, 0]))
    #Nx.Tensor<
      u8[3]
      [1, 0, 0]
    >

    iex> Nx.is_nan(Nx.tensor([:nan, :infinity, Complex.new(0, :nan)]))
    #Nx.Tensor<
      u8[3]
      [1, 0, 1]
    >

    iex> Nx.is_nan(Nx.tensor([1, 0]))
    #Nx.Tensor<
      u8[2]
      [0, 0]
    >

## is_infinity/1

Determines if each element in `tensor` is `Inf` or `-Inf`.

For complex tensors, if either of the components is infinity,
the entry is deemed infinity as well.

## Examples

    iex> Nx.is_infinity(Nx.tensor([:infinity, :nan, :neg_infinity, 1, 0]))
    #Nx.Tensor<
      u8[5]
      [1, 0, 1, 0, 0]
    >

    iex> Nx.is_infinity(Nx.tensor([:infinity, 1, Complex.new(0, :infinity), :neg_infinity]))
    #Nx.Tensor<
      u8[4]
      [1, 0, 1, 1]
    >

    iex> Nx.is_infinity(Nx.tensor([1, 0]))
    #Nx.Tensor<
      u8[2]
      [0, 0]
    >

## negate/1

Negates each element in the tensor.

If you're using `Nx.Defn.defn/2`, you can use the `-` unary operator
in place of this function: `-tensor`.

## Examples

    iex> Nx.negate(1)
    #Nx.Tensor<
      s32
      -1
    >

    iex> Nx.negate(Nx.tensor([-1, 0, 1]))
    #Nx.Tensor<
      s32[3]
      [1, 0, -1]
    >

    iex> Nx.negate(Nx.tensor([1.0, 2.0, 3.0], type: :f32))
    #Nx.Tensor<
      f32[3]
      [-1.0, -2.0, -3.0]
    >

If an unsigned tensor is given, it works as `bitwise_not`:

    iex> Nx.negate(Nx.tensor([0, 1, 2], type: :u8, names: [:x]))
    #Nx.Tensor<
      u8[x: 3]
      [0, 255, 254]
    >

## sign/1

Computes the sign of each element in the tensor.

If a number is less than zero, it returns -1.
If a number is more than zero, it returns 1.
Otherwise it returns zero (which may either be
positive or negative for floats).

## Examples

    iex> Nx.sign(Nx.tensor([-2, -1, 0, 1, 2], names: [:x]))
    #Nx.Tensor<
      s32[x: 5]
      [-1, -1, 0, 1, 1]
    >

## abs/1

Computes the absolute value of each element in the tensor.

## Examples

    iex> Nx.abs(Nx.tensor([-2, -1, 0, 1, 2], names: [:x]))
    #Nx.Tensor<
      s32[x: 5]
      [2, 1, 0, 1, 2]
    >

## conjugate/1

Calculates the complex conjugate of each element in the tensor.

If $$z = a + bi = r e^\theta$$, $$conjugate(z) = z^* = a - bi =  r e^{-\theta}$$

## Examples

     iex> Nx.conjugate(Complex.new(1, 2))
     #Nx.Tensor<
       c64
       1.0-2.0i
     >

     iex> Nx.conjugate(1)
     #Nx.Tensor<
       c64
       1.0-0.0i
     >

     iex> Nx.conjugate(Nx.tensor([Complex.new(1, 2), Complex.new(2, -4)]))
     #Nx.Tensor<
       c64[2]
       [1.0-2.0i, 2.0+4.0i]
     >

## phase/1

Calculates the complex phase angle of each element in the tensor.
$$phase(z) = atan2(b, a), z = a + bi \in \Complex$$

## Examples

     iex> Nx.phase(Complex.new(1, 2))
     #Nx.Tensor<
       f32
       1.1071488
     >

     iex> Nx.phase(1)
     #Nx.Tensor<
       f32
       0.0
     >

     iex> import Nx, only: [sigil_VEC: 2]
     iex> Nx.phase(~VEC[1+2i -2+1i])
     #Nx.Tensor<
       f32[2]
       [1.1071488, 2.6779451]
     >

## real/1

Returns the real component of each entry in a complex tensor
as a floating point tensor.

## Examples

    iex> Nx.real(Complex.new(1, 2))
    #Nx.Tensor<
      f32
      1.0
    >

    iex> Nx.real(Nx.tensor(1))
    #Nx.Tensor<
      f32
      1.0
    >

    iex> Nx.real(Nx.tensor(1, type: :bf16))
    #Nx.Tensor<
      bf16
      1.0
    >

    iex> Nx.real(Nx.tensor([Complex.new(1, 2), Complex.new(2, -4)]))
    #Nx.Tensor<
      f32[2]
      [1.0, 2.0]
    >

## imag/1

Returns the imaginary component of each entry in a complex tensor
as a floating point tensor.

## Examples

    iex> Nx.imag(Complex.new(1, 2))
    #Nx.Tensor<
      f32
      2.0
    >

    iex> Nx.imag(Nx.tensor(1))
    #Nx.Tensor<
      f32
      0.0
    >

    iex> Nx.imag(Nx.tensor(1, type: :bf16))
    #Nx.Tensor<
      bf16
      0.0
    >

    iex> Nx.imag(Nx.tensor([Complex.new(1, 2), Complex.new(2, -4)]))
    #Nx.Tensor<
      f32[2]
      [2.0, -4.0]
    >

## complex/2

Constructs a complex tensor from two equally-shaped tensors.

Does not accept complex tensors as inputs.

## Examples

    iex> Nx.complex(Nx.tensor(1), Nx.tensor(2))
    #Nx.Tensor<
      c64
      1.0+2.0i
    >

    iex> Nx.complex(Nx.tensor([1, 2]), Nx.tensor([3, 4]))
    #Nx.Tensor<
      c64[2]
      [1.0+3.0i, 2.0+4.0i]
    >

## bitwise_not/1

Applies bitwise not to each element in the tensor.

## Examples

    iex> Nx.bitwise_not(1)
    #Nx.Tensor<
      s32
      -2
    >

    iex> Nx.bitwise_not(Nx.tensor([-1, 0, 1], type: :s8, names: [:x]))
    #Nx.Tensor<
      s8[x: 3]
      [0, -1, -2]
    >

    iex> Nx.bitwise_not(Nx.tensor([0, 1, 254, 255], type: :u8, names: [:x]))
    #Nx.Tensor<
      u8[x: 4]
      [255, 254, 1, 0]
    >

## Error cases

    iex> Nx.bitwise_not(Nx.tensor([0.0, 1.0]))
    ** (ArgumentError) bitwise operators expect integer tensors as inputs and outputs an integer tensor, got: {:f, 32}

## population_count/1

Computes the bitwise population count of each element in the tensor.

## Examples

    iex> Nx.population_count(1)
    #Nx.Tensor<
      s32
      1
    >

    iex> Nx.population_count(-128)
    #Nx.Tensor<
      s32
      25
    >

    iex> Nx.population_count(Nx.tensor([0, 1, 254, 255], names: [:x]))
    #Nx.Tensor<
      s32[x: 4]
      [0, 1, 7, 8]
    >

    iex> Nx.population_count(Nx.tensor([0, 1, 126, 127, -1, -127, -128], type: :s8, names: [:x]))
    #Nx.Tensor<
      s8[x: 7]
      [0, 1, 6, 7, 8, 2, 1]
    >

## Error cases

    iex> Nx.population_count(Nx.tensor([0.0, 1.0]))
    ** (ArgumentError) bitwise operators expect integer tensors as inputs and outputs an integer tensor, got: {:f, 32}

## count_leading_zeros/1

Counts the number of leading zeros of each element in the tensor.

## Examples

    iex> Nx.count_leading_zeros(1)
    #Nx.Tensor<
      s32
      31
    >

    iex> Nx.count_leading_zeros(-1)
    #Nx.Tensor<
      s32
      0
    >

    iex> Nx.count_leading_zeros(Nx.tensor([0, 0xF, 0xFF, 0xFFFF], names: [:x]))
    #Nx.Tensor<
      s32[x: 4]
      [32, 28, 24, 16]
    >

    iex> Nx.count_leading_zeros(Nx.tensor([0xF0000000, 0x0F000000], names: [:x]))
    #Nx.Tensor<
      s32[x: 2]
      [0, 4]
    >

    iex> Nx.count_leading_zeros(Nx.tensor([0, 0xF, 0xFF, 0xFFFF], type: :s64, names: [:x]))
    #Nx.Tensor<
      s64[x: 4]
      [64, 60, 56, 48]
    >

    iex> Nx.count_leading_zeros(Nx.tensor([0, 0xF, 0xFF, 0xFFFF], type: :s16, names: [:x]))
    #Nx.Tensor<
      s16[x: 4]
      [16, 12, 8, 0]
    >

    iex> Nx.count_leading_zeros(Nx.tensor([0, 1, 2, 4, 8, 16, 32, 64, -1, -128], type: :s8, names: [:x]))
    #Nx.Tensor<
      s8[x: 10]
      [8, 7, 6, 5, 4, 3, 2, 1, 0, 0]
    >

    iex> Nx.count_leading_zeros(Nx.tensor([0, 1, 2, 4, 8, 16, 32, 64, 128], type: :u8, names: [:x]))
    #Nx.Tensor<
      u8[x: 9]
      [8, 7, 6, 5, 4, 3, 2, 1, 0]
    >

## Error cases

    iex> Nx.count_leading_zeros(Nx.tensor([0.0, 1.0]))
    ** (ArgumentError) bitwise operators expect integer tensors as inputs and outputs an integer tensor, got: {:f, 32}

## all/2

Returns a scalar tensor of value 1 if all of the
tensor values are not zero. Otherwise the value is 0.

If the `:axes` option is given, it aggregates over
the given dimensions, effectively removing them.
`axes: [0]` implies aggregating over the highest order
dimension and so forth. If the axis is negative, then
counts the axis from the back. For example, `axes: [-1]`
will always aggregate all rows.

You may optionally set `:keep_axes` to true, which will
retain the rank of the input tensor by setting the reduced
axes to size 1.

## Examples

    iex> Nx.all(Nx.tensor([0, 1, 2]))
    #Nx.Tensor<
      u8
      0
    >

    iex> Nx.all(Nx.tensor([[-1, 0, 1], [2, 3, 4]], names: [:x, :y]), axes: [:x])
    #Nx.Tensor<
      u8[y: 3]
      [1, 0, 1]
    >

    iex> Nx.all(Nx.tensor([[-1, 0, 1], [2, 3, 4]], names: [:x, :y]), axes: [:y])
    #Nx.Tensor<
      u8[x: 2]
      [0, 1]
    >

### Keeping axes

    iex> Nx.all(Nx.tensor([[-1, 0, 1], [2, 3, 4]], names: [:x, :y]), axes: [:y], keep_axes: true)
    #Nx.Tensor<
      u8[x: 2][y: 1]
      [
        [0],
        [1]
      ]
    >

### Vectorized tensors

    iex> t = Nx.vectorize(Nx.tensor([[0, 1], [1, 1]]), :x)
    iex> Nx.all(t, axes: [0], keep_axes: true)
    #Nx.Tensor<
      vectorized[x: 2]
      u8[1]
      [
        [0],
        [1]
      ]
    >

    iex> t = Nx.vectorize(Nx.tensor([1, 0]), :x)
    iex> Nx.all(t)
    #Nx.Tensor<
      vectorized[x: 2]
      u8
      [1, 0]
    >

## any/2

Returns a scalar tensor of value 1 if any of the
tensor values are not zero. Otherwise the value is 0.

If the `:axes` option is given, it aggregates over
the given dimensions, effectively removing them.
`axes: [0]` implies aggregating over the highest order
dimension and so forth. If the axis is negative, then
counts the axis from the back. For example, `axes: [-1]`
will always aggregate all rows.

You may optionally set `:keep_axes` to true, which will
retain the rank of the input tensor by setting the reduced
axes to size 1.

## Examples

    iex> Nx.any(Nx.tensor([0, 1, 2]))
    #Nx.Tensor<
      u8
      1
    >

    iex> Nx.any(Nx.tensor([[0, 1, 0], [0, 1, 2]], names: [:x, :y]), axes: [:x])
    #Nx.Tensor<
      u8[y: 3]
      [0, 1, 1]
    >

    iex> Nx.any(Nx.tensor([[0, 1, 0], [0, 1, 2]], names: [:x, :y]), axes: [:y])
    #Nx.Tensor<
      u8[x: 2]
      [1, 1]
    >

### Keeping axes

    iex> Nx.any(Nx.tensor([[0, 1, 0], [0, 1, 2]], names: [:x, :y]), axes: [:y], keep_axes: true)
    #Nx.Tensor<
      u8[x: 2][y: 1]
      [
        [1],
        [1]
      ]
    >

### Vectorized tensors

    iex> t = Nx.vectorize(Nx.tensor([[0, 1], [0, 0]]), :x)
    iex> Nx.any(t, axes: [0], keep_axes: true)
    #Nx.Tensor<
      vectorized[x: 2]
      u8[1]
      [
        [1],
        [0]
      ]
    >

## all_close/3

Returns a scalar tensor of value 1 if all element-wise values
are within tolerance of b. Otherwise returns value 0.

You may set the absolute tolerance, `:atol` and relative tolerance
`:rtol`. Given tolerances, this functions returns 1 if

    absolute(a - b) <= (atol + rtol * absolute(b))

is true for all elements of a and b.

For **integer** tensors, `absolute(b)` in the tolerance bound is evaluated in
`f64` so that the most negative signed value (e.g. `s8` `-128`) does not
overflow `abs` in the original narrow type.

## Options

 * `:rtol` - relative tolerance between numbers, as described above. Defaults to 1.0e-5
 * `:atol` - absolute tolerance between numbers, as described above. Defaults to 1.0e-8
 * `:equal_nan` - if `false`, NaN will always compare as false.
   Otherwise `NaN` will only equal `NaN`. Defaults to `false`

## Examples

    iex> Nx.all_close(Nx.tensor([1.0e10, 1.0e-7]), Nx.tensor([1.00001e10, 1.0e-8]))
    #Nx.Tensor<
      u8
      0
    >

    iex> Nx.all_close(Nx.tensor([1.0e-8, 1.0e-8]), Nx.tensor([1.0e-8, 1.0e-9]))
    #Nx.Tensor<
      u8
      1
    >

Although `NaN` by definition isn't equal to itself, so this implementation
also considers all `NaN`s different from each other by default:

    iex> Nx.all_close(Nx.tensor(:nan), Nx.tensor(:nan))
    #Nx.Tensor<
      u8
      0
    >

    iex> Nx.all_close(Nx.tensor(:nan), Nx.tensor(0))
    #Nx.Tensor<
      u8
      0
    >

We can change this behavior with the `:equal_nan` option:

    iex> t = Nx.tensor([:nan, 1])
    iex> Nx.all_close(t, t, equal_nan: true) # nan == nan -> true
    #Nx.Tensor<
      u8
      1
    >
    iex> Nx.all_close(t, t, equal_nan: false) # nan == nan -> false, default behavior
    #Nx.Tensor<
      u8
      0
    >

Infinities behave as expected, being "close" to themselves but not
to other numbers:

    iex> Nx.all_close(Nx.tensor(:infinity), Nx.tensor(:infinity))
    #Nx.Tensor<
      u8
      1
    >

    iex> Nx.all_close(Nx.tensor(:infinity), Nx.tensor(:neg_infinity))
    #Nx.Tensor<
      u8
      0
    >

    iex> Nx.all_close(Nx.tensor(1.0e30), Nx.tensor(:infinity))
    #Nx.Tensor<
      u8
      0
    >

Integer tensors where `b` contains the minimum signed value (e.g. `s8` `-128`) still compare equal to themselves:

    iex> a = Nx.tensor([[5, 6], [7, 8]], type: :s8)
    iex> b = Nx.tensor([[1, 2], [3, 4]], type: :s8)
    iex> x = Nx.left_shift(a, b)
    iex> Nx.all_close(x, x)
    #Nx.Tensor<
      u8
      1
    >

## Vectorized tensors

Vectorized inputs have their vectorized axes broadcast together
before calculations are performed.

    iex> x = Nx.tensor([0, 1]) |> Nx.vectorize(:x)
    iex> Nx.all_close(x, x)
    #Nx.Tensor<
      vectorized[x: 2]
      u8
      [1, 1]
    >

    iex> x = Nx.tensor([0, 1, 2]) |> Nx.vectorize(:x)
    iex> y = Nx.tensor([0, 1]) |> Nx.vectorize(:y)
    iex> Nx.all_close(x, y)
    #Nx.Tensor<
      vectorized[x: 3][y: 2]
      u8
      [
        [1, 0],
        [0, 1],
        [0, 0]
      ]
    >

## sum/2

Returns the sum for the tensor.

If the `:axes` option is given, it aggregates over
the given dimensions, effectively removing them.
`axes: [0]` implies aggregating over the highest order
dimension and so forth. If the axis is negative, then
counts the axis from the back. For example, `axes: [-1]`
will always aggregate all rows.

You may optionally set `:keep_axes` to true, which will
retain the rank of the input tensor by setting the summed
axes to size 1.

## Examples

By default the sum always returns a scalar:

    iex> Nx.sum(Nx.tensor(42))
    #Nx.Tensor<
      s32
      42
    >

    iex> Nx.sum(Nx.tensor([1, 2, 3]))
    #Nx.Tensor<
      s32
      6
    >

    iex> Nx.sum(Nx.tensor([[1.0, 2.0], [3.0, 4.0]]))
    #Nx.Tensor<
      f32
      10.0
    >

Giving a tensor with low precision casts it to a higher
precision to make sure the sum does not overflow:

    iex> Nx.sum(Nx.tensor([[101, 102], [103, 104]], type: :s8))
    #Nx.Tensor<
      s32
      410
    >

    iex> Nx.sum(Nx.tensor([[101, 102], [103, 104]], type: :s16))
    #Nx.Tensor<
      s32
      410
    >

### Aggregating over an axis

    iex> Nx.sum(Nx.tensor([1, 2, 3]), axes: [0])
    #Nx.Tensor<
      s32
      6
    >

Same tensor over different axes combinations:

    iex> t = Nx.iota({2, 2, 3}, names: [:x, :y, :z])
    iex> Nx.sum(t, axes: [:x])
    #Nx.Tensor<
      s32[y: 2][z: 3]
      [
        [6, 8, 10],
        [12, 14, 16]
      ]
    >
    iex> Nx.sum(t, axes: [:y])
    #Nx.Tensor<
      s32[x: 2][z: 3]
      [
        [3, 5, 7],
        [15, 17, 19]
      ]
    >
    iex> Nx.sum(t, axes: [:z])
    #Nx.Tensor<
      s32[x: 2][y: 2]
      [
        [3, 12],
        [21, 30]
      ]
    >
    iex> Nx.sum(t, axes: [:x, :z])
    #Nx.Tensor<
      s32[y: 2]
      [24, 42]
    >
    iex> Nx.sum(t, axes: [-3])
    #Nx.Tensor<
      s32[y: 2][z: 3]
      [
        [6, 8, 10],
        [12, 14, 16]
      ]
    >

### Keeping axes

    iex> t = Nx.tensor([[1, 2], [3, 4]], names: [:x, :y])
    iex> Nx.sum(t, axes: [:x], keep_axes: true)
    #Nx.Tensor<
      s32[x: 1][y: 2]
      [
        [4, 6]
      ]
    >

### Vectorized tensors

    iex> t = Nx.tensor([[[[1, 2]], [[3, 4]]], [[[5, 6]], [[7, 8]]]]) |> Nx.vectorize(:x) |> Nx.vectorize(:y)
    #Nx.Tensor<
      vectorized[x: 2][y: 2]
      s32[1][2]
      [
        [
          [
            [1, 2]
          ],
          [
            [3, 4]
          ]
        ],
        [
          [
            [5, 6]
          ],
          [
            [7, 8]
          ]
        ]
      ]
    >
    iex> Nx.sum(t)
    #Nx.Tensor<
      vectorized[x: 2][y: 2]
      s32
      [
        [3, 7],
        [11, 15]
      ]
    >
    iex> Nx.sum(t, axes: [0])
    #Nx.Tensor<
      vectorized[x: 2][y: 2]
      s32[2]
      [
        [
          [1, 2],
          [3, 4]
        ],
        [
          [5, 6],
          [7, 8]
        ]
      ]
    >

### Errors

    iex> Nx.sum(Nx.tensor([[1, 2]]), axes: [2])
    ** (ArgumentError) given axis (2) invalid for shape with rank 2

## mean/2

Returns the mean for the tensor.

If the `:axes` option is given, it aggregates over
that dimension, effectively removing it. `axes: [0]`
implies aggregating over the highest order dimension
and so forth. If the axis is negative, then counts
the axis from the back. For example, `axes: [-1]` will
always aggregate all rows.

You may optionally set `:keep_axes` to true, which will
retain the rank of the input tensor by setting the averaged
axes to size 1.

## Examples

    iex> Nx.mean(Nx.tensor(42))
    #Nx.Tensor<
      f32
      42.0
    >

    iex> Nx.mean(Nx.tensor([1, 2, 3]))
    #Nx.Tensor<
      f32
      2.0
    >

### Aggregating over an axis

    iex> Nx.mean(Nx.tensor([1, 2, 3]), axes: [0])
    #Nx.Tensor<
      f32
      2.0
    >

    iex> Nx.mean(Nx.tensor([1, 2, 3], type: :u8, names: [:x]), axes: [:x])
    #Nx.Tensor<
      f32
      2.0
    >

    iex> t = Nx.tensor(Nx.iota({2, 2, 3}), names: [:x, :y, :z])
    iex> Nx.mean(t, axes: [:x])
    #Nx.Tensor<
      f32[y: 2][z: 3]
      [
        [3.0, 4.0, 5.0],
        [6.0, 7.0, 8.0]
      ]
    >

    iex> t = Nx.tensor(Nx.iota({2, 2, 3}), names: [:x, :y, :z])
    iex> Nx.mean(t, axes: [:x, :z])
    #Nx.Tensor<
      f32[y: 2]
      [4.0, 7.0]
    >

    iex> t = Nx.tensor(Nx.iota({2, 2, 3}), names: [:x, :y, :z])
    iex> Nx.mean(t, axes: [-1])
    #Nx.Tensor<
      f32[x: 2][y: 2]
      [
        [1.0, 4.0],
        [7.0, 10.0]
      ]
    >

### Keeping axes

    iex> t = Nx.tensor(Nx.iota({2, 2, 3}), names: [:x, :y, :z])
    iex> Nx.mean(t, axes: [-1], keep_axes: true)
    #Nx.Tensor<
      f32[x: 2][y: 2][z: 1]
      [
        [
          [1.0],
          [4.0]
        ],
        [
          [7.0],
          [10.0]
        ]
      ]
    >

## Vectorized tensors

    iex> t = Nx.iota({2, 5}, vectorized_axes: [x: 2])
    iex> Nx.mean(t)
    #Nx.Tensor<
      vectorized[x: 2]
      f32
      [4.5, 4.5]
    >
    iex> Nx.mean(t, axes: [0])
    #Nx.Tensor<
      vectorized[x: 2]
      f32[5]
      [
        [2.5, 3.5, 4.5, 5.5, 6.5],
        [2.5, 3.5, 4.5, 5.5, 6.5]
      ]
    >
    iex> Nx.mean(t, axes: [1])
    #Nx.Tensor<
      vectorized[x: 2]
      f32[2]
      [
        [2.0, 7.0],
        [2.0, 7.0]
      ]
    >

## weighted_mean/3

Returns the weighted mean for the tensor and the weights.

If the `:axes` option is given, it aggregates over
those dimensions, effectively removing them. `axes: [0]`
implies aggregating over the highest order dimension
and so forth. If the axes are negative, then the axes will
be counted from the back. For example, `axes: [-1]` will
always aggregate over the last dimension.

You may optionally set `:keep_axes` to true, which will
retain the rank of the input tensor by setting the averaged
axes to size 1.

## Examples

    iex> Nx.weighted_mean(Nx.tensor(42), Nx.tensor(2))
    #Nx.Tensor<
      f32
      42.0
    >

    iex> Nx.weighted_mean(Nx.tensor([1, 2, 3]), Nx.tensor([3, 2, 1]))
    #Nx.Tensor<
      f32
      1.6666666
    >

### Aggregating over axes

    iex> Nx.weighted_mean(Nx.tensor([1, 2, 3], names: [:x]), Nx.tensor([4, 5, 6]), axes: [0])
    #Nx.Tensor<
      f32
      2.1333334
    >

    iex> Nx.weighted_mean(Nx.tensor([1, 2, 3], type: :u8, names: [:x]), Nx.tensor([1, 3, 5]), axes: [:x])
    #Nx.Tensor<
      f32
      2.4444444
    >

    iex> t = Nx.iota({3, 4})
    iex> weights = Nx.tensor([1, 2, 3, 4])
    iex> Nx.weighted_mean(t, weights, axes: [1])
    #Nx.Tensor<
      f32[3]
      [2.0, 6.0, 10.0]
    >

    iex> t = Nx.iota({2, 4, 4, 1})
    iex> weights = Nx.broadcast(2, {4, 4})
    iex> Nx.weighted_mean(t, weights, axes: [1, 2])
    #Nx.Tensor<
      f32[2][1]
      [
        [7.5],
        [23.5]
      ]
    >

### Keeping axes

    iex> t = Nx.tensor(Nx.iota({2, 2, 3}), names: [:x, :y, :z])
    iex> weights = Nx.tensor([[[0, 1, 2], [1, 1, 0]], [[-1, 1, -1], [1, 1, -1]]])
    iex> Nx.weighted_mean(t, weights, axes: [-1], keep_axes: true)
    #Nx.Tensor<
      f32[x: 2][y: 2][z: 1]
      [
        [
          [1.6666666],
          [3.5]
        ],
        [
          [7.0],
          [8.0]
        ]
      ]
    >

### Vectorized tensors

    iex> t = Nx.tensor([[1, 2, 3], [1, 1, 1]]) |> Nx.vectorize(:x)
    #Nx.Tensor<
      vectorized[x: 2]
      s32[3]
      [
        [1, 2, 3],
        [1, 1, 1]
      ]
    >
    iex> w = Nx.tensor([[1, 1, 1], [0, 0, 1]]) |> Nx.vectorize(:y)
    #Nx.Tensor<
      vectorized[y: 2]
      s32[3]
      [
        [1, 1, 1],
        [0, 0, 1]
      ]
    >
    iex> Nx.weighted_mean(t, w)
    #Nx.Tensor<
      vectorized[x: 2][y: 2]
      f32
      [
        [2.0, 3.0],
        [1.0, 1.0]
      ]
    >

## median/2

Returns the median for the tensor.

The median is the value in the middle of a data set.

If the `:axis` option is given, it aggregates over
that dimension, effectively removing it. `axis: 0`
implies aggregating over the highest order dimension
and so forth. If the axis is negative, then the axis will
be counted from the back. For example, `axis: -1` will
always aggregate over the last dimension.

You may optionally set `:keep_axis` to true, which will
retain the rank of the input tensor by setting the reduced
axis to size 1.

## Examples

    iex> Nx.median(Nx.tensor(42))
    #Nx.Tensor<
      s32
      42
    >

    iex> Nx.median(Nx.tensor([1, 2, 3]))
    #Nx.Tensor<
      s32
      2
    >

    iex> Nx.median(Nx.tensor([1, 2]))
    #Nx.Tensor<
      f32
      1.5
    >

    iex> Nx.median(Nx.iota({2, 3, 3}))
    #Nx.Tensor<
      f32
      8.5
    >

### Aggregating over an axis

    iex> Nx.median(Nx.tensor([[1, 2, 3], [4, 5, 6]], names: [:x, :y]), axis: 0)
    #Nx.Tensor<
      f32[y: 3]
      [2.5, 3.5, 4.5]
    >

    iex> Nx.median(Nx.tensor([[1, 2, 3], [4, 5, 6]], names: [:x, :y]), axis: :y)
    #Nx.Tensor<
      s32[x: 2]
      [2, 5]
    >

    iex> t = Nx.tensor(Nx.iota({2, 2, 3}), names: [:x, :y, :z])
    iex> Nx.median(t, axis: :x)
    #Nx.Tensor<
      f32[y: 2][z: 3]
      [
        [3.0, 4.0, 5.0],
        [6.0, 7.0, 8.0]
      ]
    >

    iex> t = Nx.tensor([[[1, 2, 2], [3, 4, 2]], [[4, 5, 2], [7, 9, 2]]])
    iex> Nx.median(t, axis: -1)
    #Nx.Tensor<
      s32[2][2]
      [
        [2, 3],
        [4, 7]
      ]
    >

### Keeping axis

    iex> t = Nx.tensor([[[1, 2, 2], [3, 4, 2]], [[4, 5, 2], [7, 9, 2]]])
    iex> Nx.median(t, axis: -1, keep_axis: true)
    #Nx.Tensor<
      s32[2][2][1]
      [
        [
          [2],
          [3]
        ],
        [
          [4],
          [7]
        ]
      ]
    >

### Vectorized tensors

For vectorized inputs, `:axis` refers to the
non-vectorized shape:

    iex> Nx.median(Nx.tensor([[1, 2, 3], [4, 5, 6]]) |> Nx.vectorize(:x), axis: 0)
    #Nx.Tensor<
      vectorized[x: 2]
      s32
      [2, 5]
    >

## mode/2

Returns the mode of a tensor.

The mode is the value that appears most often.

If the `:axis` option is given, it aggregates over
that dimension, effectively removing it. `axis: 0`
implies aggregating over the highest order dimension
and so forth. If the axis is negative, then the axis will
be counted from the back. For example, `axis: -1` will
always aggregate over the last dimension.

You may optionally set `:keep_axis` to true, which will
retain the rank of the input tensor by setting the reduced
axis to size 1.

## Examples

    iex> Nx.mode(Nx.tensor(42))
    #Nx.Tensor<
      s32
      42
    >

    iex> Nx.mode(Nx.tensor([[1]]))
    #Nx.Tensor<
      s32
      1
    >

    iex> Nx.mode(Nx.tensor([1, 2, 2, 3, 5]))
    #Nx.Tensor<
      s32
      2
    >

    iex> Nx.mode(Nx.tensor([[1, 2, 2, 3, 5], [1, 1, 76, 8, 1]]))
    #Nx.Tensor<
      s32
      1
    >

### Aggregating over an axis

    iex> Nx.mode(Nx.tensor([[1, 2, 2, 3, 5], [1, 1, 76, 8, 1]]), axis: 0)
    #Nx.Tensor<
      s32[5]
      [1, 1, 2, 3, 1]
    >

    iex> Nx.mode(Nx.tensor([[1, 2, 2, 3, 5], [1, 1, 76, 8, 1]]), axis: 1)
    #Nx.Tensor<
      s32[2]
      [2, 1]
    >

    iex> Nx.mode(Nx.tensor([[[1]]]), axis: 1)
    #Nx.Tensor<
      s32[1][1]
      [
        [1]
      ]
    >

### Keeping axis

    iex> Nx.mode(Nx.tensor([[1, 2, 2, 3, 5], [1, 1, 76, 8, 1]]), axis: 1, keep_axis: true)
    #Nx.Tensor<
      s32[2][1]
      [
        [2],
        [1]
      ]
    >

### Vectorized tensors

For vectorized tensors, `:axis` refers to the non-vectorized shape:

    iex> t = Nx.tensor([[[1, 2, 2, 3, 5], [1, 1, 76, 8, 1]], [[1, 2, 2, 2, 5], [5, 2, 2, 2, 1]]]) |> Nx.vectorize(:x)
    iex> Nx.mode(t, axis: 0)
    #Nx.Tensor<
      vectorized[x: 2]
      s32[5]
      [
        [1, 1, 2, 3, 1],
        [1, 2, 2, 2, 1]
      ]
    >
    iex> Nx.mode(t, axis: 1)
    #Nx.Tensor<
      vectorized[x: 2]
      s32[2]
      [
        [2, 1],
        [2, 2]
      ]
    >

## product/2

Returns the product for the tensor.

If the `:axes` option is given, it aggregates over
the given dimensions, effectively removing them.
`axes: [0]` implies aggregating over the highest order
dimension and so forth. If the axis is negative, then
counts the axis from the back. For example, `axes: [-1]`
will always aggregate all rows.

You may optionally set `:keep_axes` to true, which will
retain the rank of the input tensor by setting the multiplied
axes to size 1.

## Examples

By default the product always returns a scalar:

    iex> Nx.product(Nx.tensor(42))
    #Nx.Tensor<
      s32
      42
    >

    iex> Nx.product(Nx.tensor([1, 2, 3]))
    #Nx.Tensor<
      s32
      6
    >

    iex> Nx.product(Nx.tensor([[1.0, 2.0], [3.0, 4.0]]))
    #Nx.Tensor<
      f32
      24.0
    >

Giving a tensor with low precision casts it to a higher
precision to make sure the sum does not overflow:

    iex> Nx.product(Nx.tensor([[10, 20], [30, 40]], type: :u8, names: [:x, :y]))
    #Nx.Tensor<
      u32
      240000
    >

    iex> Nx.product(Nx.tensor([[10, 20], [30, 40]], type: :s8, names: [:x, :y]))
    #Nx.Tensor<
      s32
      240000
    >

### Aggregating over an axis

    iex> Nx.product(Nx.tensor([1, 2, 3]), axes: [0])
    #Nx.Tensor<
      s32
      6
    >

Same tensor over different axes combinations:

    iex> t = Nx.iota({2, 2, 3}, names: [:x, :y, :z])
    iex> Nx.product(t, axes: [:x])
    #Nx.Tensor<
      s32[y: 2][z: 3]
      [
        [0, 7, 16],
        [27, 40, 55]
      ]
    >
    iex> Nx.product(t, axes: [:y])
    #Nx.Tensor<
      s32[x: 2][z: 3]
      [
        [0, 4, 10],
        [54, 70, 88]
      ]
    >
    iex> Nx.product(t, axes: [:x, :z])
    #Nx.Tensor<
      s32[y: 2]
      [0, 59400]
    >
    iex> Nx.product(t, axes: [:z])
    #Nx.Tensor<
      s32[x: 2][y: 2]
      [
        [0, 60],
        [336, 990]
      ]
    >
    iex> Nx.product(t, axes: [-3])
    #Nx.Tensor<
      s32[y: 2][z: 3]
      [
        [0, 7, 16],
        [27, 40, 55]
      ]
    >

### Keeping axes

    iex> t = Nx.iota({2, 2, 3}, names: [:x, :y, :z])
    iex> Nx.product(t, axes: [:z], keep_axes: true)
    #Nx.Tensor<
      s32[x: 2][y: 2][z: 1]
      [
        [
          [0],
          [60]
        ],
        [
          [336],
          [990]
        ]
      ]
    >

### Vectorized tensors

    iex> t = Nx.vectorize(Nx.tensor([[1, 2], [3, 4]]), :x)
    iex> Nx.product(t, axes: [0], keep_axes: true)
    #Nx.Tensor<
      vectorized[x: 2]
      s32[1]
      [
        [2],
        [12]
      ]
    >

### Errors

    iex> Nx.product(Nx.tensor([[1, 2]]), axes: [2])
    ** (ArgumentError) given axis (2) invalid for shape with rank 2

## reduce_max/2

Returns the maximum values of the tensor.

If the `:axes` option is given, it aggregates over
the given dimensions, effectively removing them.
`axes: [0]` implies aggregating over the highest order
dimension and so forth. If the axis is negative, then
counts the axis from the back. For example, `axes: [-1]`
will always aggregate all rows.

You may optionally set `:keep_axes` to true, which will
retain the rank of the input tensor by setting the reduced
axes to size 1.

## Examples

    iex> Nx.reduce_max(Nx.tensor(42))
    #Nx.Tensor<
      s32
      42
    >

    iex> Nx.reduce_max(Nx.tensor(42.0))
    #Nx.Tensor<
      f32
      42.0
    >

    iex> Nx.reduce_max(Nx.tensor([1, 2, 3]))
    #Nx.Tensor<
      s32
      3
    >

### Aggregating over an axis

    iex> t = Nx.tensor([[3, 1, 4], [2, 1, 1]], names: [:x, :y])
    iex> Nx.reduce_max(t, axes: [:x])
    #Nx.Tensor<
      s32[y: 3]
      [3, 1, 4]
    >

    iex> t = Nx.tensor([[3, 1, 4], [2, 1, 1]], names: [:x, :y])
    iex> Nx.reduce_max(t, axes: [:y])
    #Nx.Tensor<
      s32[x: 2]
      [4, 2]
    >

    iex> t = Nx.tensor([[[1, 2], [4, 5]], [[2, 4], [3, 8]]], names: [:x, :y, :z])
    iex> Nx.reduce_max(t, axes: [:x, :z])
    #Nx.Tensor<
      s32[y: 2]
      [4, 8]
    >

### Keeping axes

    iex> t = Nx.tensor([[[1, 2], [4, 5]], [[2, 4], [3, 8]]], names: [:x, :y, :z])
    iex> Nx.reduce_max(t, axes: [:x, :z], keep_axes: true)
    #Nx.Tensor<
      s32[x: 1][y: 2][z: 1]
      [
        [
          [4],
          [8]
        ]
      ]
    >

### Vectorized tensors

    iex> t = Nx.vectorize(Nx.tensor([[1, 2], [3, 4]]), :x)
    iex> Nx.reduce_max(t, axes: [0], keep_axes: true)
    #Nx.Tensor<
      vectorized[x: 2]
      s32[1]
      [
        [2],
        [4]
      ]
    >

## reduce_min/2

Returns the minimum values of the tensor.

If the `:axes` option is given, it aggregates over
the given dimensions, effectively removing them.
`axes: [0]` implies aggregating over the highest order
dimension and so forth. If the axis is negative, then
counts the axis from the back. For example, `axes: [-1]`
will always aggregate all rows.

You may optionally set `:keep_axes` to true, which will
retain the rank of the input tensor by setting the reduced
axes to size 1.

## Examples

    iex> Nx.reduce_min(Nx.tensor(42))
    #Nx.Tensor<
      s32
      42
    >

    iex> Nx.reduce_min(Nx.tensor(42.0))
    #Nx.Tensor<
      f32
      42.0
    >

    iex> Nx.reduce_min(Nx.tensor([1, 2, 3]))
    #Nx.Tensor<
      s32
      1
    >

### Aggregating over an axis

    iex> t = Nx.tensor([[3, 1, 4], [2, 1, 1]], names: [:x, :y])
    iex> Nx.reduce_min(t, axes: [:x])
    #Nx.Tensor<
      s32[y: 3]
      [2, 1, 1]
    >

    iex> t = Nx.tensor([[3, 1, 4], [2, 1, 1]], names: [:x, :y])
    iex> Nx.reduce_min(t, axes: [:y])
    #Nx.Tensor<
      s32[x: 2]
      [1, 1]
    >

    iex> t = Nx.tensor([[[1, 2], [4, 5]], [[2, 4], [3, 8]]], names: [:x, :y, :z])
    iex> Nx.reduce_min(t, axes: [:x, :z])
    #Nx.Tensor<
      s32[y: 2]
      [1, 3]
    >

### Keeping axes

    iex> t = Nx.tensor([[[1, 2], [4, 5]], [[2, 4], [3, 8]]], names: [:x, :y, :z])
    iex> Nx.reduce_min(t, axes: [:x, :z], keep_axes: true)
    #Nx.Tensor<
      s32[x: 1][y: 2][z: 1]
      [
        [
          [1],
          [3]
        ]
      ]
    >

### Vectorized tensors

    iex> t = Nx.vectorize(Nx.tensor([[1, 2], [3, 4]]), :x)
    iex> Nx.reduce_min(t, axes: [0], keep_axes: true)
    #Nx.Tensor<
      vectorized[x: 2]
      s32[1]
      [
        [1],
        [3]
      ]
    >

## argmax/2

Returns the indices of the maximum values.

## Options

  * `:axis` - the axis to aggregate on. If no axis is given,
    returns the index of the absolute maximum value in the tensor.

  * `:keep_axis` - whether or not to keep the reduced axis with
    a size of 1. Defaults to `false`.

  * `:tie_break` - how to break ties. one of `:high`, or `:low`.
    default behavior is to always return the lower index.

  * `:type` - The type of the resulting tensor. Defaults to `:s32`.

## Examples

    iex> Nx.argmax(4)
    #Nx.Tensor<
      s32
      0
    >

    iex> t = Nx.tensor([[[4, 2, 3], [1, -5, 3]], [[6, 2, 3], [4, 8, 3]]])
    iex> Nx.argmax(t)
    #Nx.Tensor<
      s32
      10
    >

If a tensor of floats is given, it still returns integers:

    iex> Nx.argmax(Nx.tensor([2.0, 4.0]))
    #Nx.Tensor<
      s32
      1
    >

If the tensor includes any NaNs, returns the index of any of them
(NaNs are not equal, hence tie-break does not apply):

    iex> Nx.argmax(Nx.tensor([2.0, :nan, 4.0]))
    #Nx.Tensor<
      s32
      1
    >

### Aggregating over an axis

    iex> t = Nx.tensor([[[4, 2, 3], [1, -5, 3]], [[6, 2, 3], [4, 8, 3]]])
    iex> Nx.argmax(t, axis: 0)
    #Nx.Tensor<
      s32[2][3]
      [
        [1, 0, 0],
        [1, 1, 0]
      ]
    >

    iex> t = Nx.tensor([[[4, 2, 3], [1, -5, 3]], [[6, 2, 3], [4, 8, 3]]], names: [:x, :y, :z])
    iex> Nx.argmax(t, axis: :y)
    #Nx.Tensor<
      s32[x: 2][z: 3]
      [
        [0, 0, 0],
        [0, 1, 0]
      ]
    >

    iex> t = Nx.tensor([[[4, 2, 3], [1, -5, 3]], [[6, 2, 3], [4, 8, 3]]], names: [:x, :y, :z])
    iex> Nx.argmax(t, axis: :z)
    #Nx.Tensor<
      s32[x: 2][y: 2]
      [
        [0, 2],
        [0, 1]
      ]
    >

### Tie breaks

    iex> t = Nx.tensor([[[4, 2, 3], [1, -5, 3]], [[6, 2, 3], [4, 8, 3]]], names: [:x, :y, :z])
    iex> Nx.argmax(t, tie_break: :low, axis: :y)
    #Nx.Tensor<
      s32[x: 2][z: 3]
      [
        [0, 0, 0],
        [0, 1, 0]
      ]
    >

    iex> t = Nx.tensor([[[4, 2, 3], [1, -5, 3]], [[6, 2, 3], [4, 8, 3]]], names: [:x, :y, :z])
    iex> Nx.argmax(t, tie_break: :high, axis: :y, type: :u32)
    #Nx.Tensor<
      u32[x: 2][z: 3]
      [
        [0, 0, 1],
        [0, 1, 1]
      ]
    >

### Keep axis

    iex> t = Nx.tensor([[[4, 2, 3], [1, -5, 3]], [[6, 2, 3], [4, 8, 3]]], names: [:x, :y, :z])
    iex> Nx.argmax(t, axis: :y, keep_axis: true)
    #Nx.Tensor<
      s32[x: 2][y: 1][z: 3]
      [
        [
          [0, 0, 0]
        ],
        [
          [0, 1, 0]
        ]
      ]
    >

### Vectorized tensors

    iex> v = Nx.tensor([[1, 2, 3], [6, 5, 4]]) |> Nx.vectorize(:x)
    iex> Nx.argmax(v)
    #Nx.Tensor<
      vectorized[x: 2]
      s32
      [2, 0]
    >
    iex> Nx.argmax(v, axis: 0)
    #Nx.Tensor<
      vectorized[x: 2]
      s32
      [2, 0]
    >
    iex> Nx.argmax(v, keep_axis: true)
    #Nx.Tensor<
      vectorized[x: 2]
      s32[1]
      [
        [2],
        [0]
      ]
    >

## argmin/2

Returns the indices of the minimum values.

## Options

  * `:axis` - the axis to aggregate on. If no axis is given,
    returns the index of the absolute minimum value in the tensor.

  * `:keep_axis` - whether or not to keep the reduced axis with
    a size of 1. Defaults to `false`.

  * `:tie_break` - how to break ties. one of `:high`, or `:low`.
    Default behavior is to always return the lower index.

  * `:type` - The type of the resulting tensor. Defaults to `:s32`.

## Examples

    iex> Nx.argmin(4)
    #Nx.Tensor<
      s32
      0
    >

    iex> t = Nx.tensor([[[4, 2, 3], [1, -5, 3]], [[6, 2, 3], [4, 8, 3]]])
    iex> Nx.argmin(t)
    #Nx.Tensor<
      s32
      4
    >

If a tensor of floats is given, it still returns integers:

    iex> Nx.argmin(Nx.tensor([2.0, 4.0]))
    #Nx.Tensor<
      s32
      0
    >

If the tensor includes any NaNs, returns the index of any of them
(NaNs are not equal, hence tie-break does not apply):

    iex> Nx.argmin(Nx.tensor([2.0, :nan, 4.0]))
    #Nx.Tensor<
      s32
      1
    >

### Aggregating over an axis

    iex> t = Nx.tensor([[[4, 2, 3], [1, -5, 3]], [[6, 2, 3], [4, 8, 3]]])
    iex> Nx.argmin(t, axis: 0)
    #Nx.Tensor<
      s32[2][3]
      [
        [0, 0, 0],
        [0, 0, 0]
      ]
    >

    iex> t = Nx.tensor([[[4, 2, 3], [1, -5, 3]], [[6, 2, 3], [4, 8, 3]]], names: [:x, :y, :z])
    iex> Nx.argmin(t, axis: 1)
    #Nx.Tensor<
      s32[x: 2][z: 3]
      [
        [1, 1, 0],
        [1, 0, 0]
      ]
    >

    iex> t = Nx.tensor([[[4, 2, 3], [1, -5, 3]], [[6, 2, 3], [4, 8, 3]]], names: [:x, :y, :z])
    iex> Nx.argmin(t, axis: :z)
    #Nx.Tensor<
      s32[x: 2][y: 2]
      [
        [1, 1],
        [1, 2]
      ]
    >

### Tie breaks

    iex> t = Nx.tensor([[[4, 2, 3], [1, -5, 3]], [[6, 2, 3], [4, 8, 3]]], names: [:x, :y, :z])
    iex> Nx.argmin(t, tie_break: :low, axis: :y)
    #Nx.Tensor<
      s32[x: 2][z: 3]
      [
        [1, 1, 0],
        [1, 0, 0]
      ]
    >

    iex> t = Nx.tensor([[[4, 2, 3], [1, -5, 3]], [[6, 2, 3], [4, 8, 3]]], names: [:x, :y, :z])
    iex> Nx.argmin(t, tie_break: :high, axis: :y, type: :u32)
    #Nx.Tensor<
      u32[x: 2][z: 3]
      [
        [1, 1, 1],
        [1, 0, 1]
      ]
    >

### Keep axis

    iex> t = Nx.tensor([[[4, 2, 3], [1, -5, 3]], [[6, 2, 3], [4, 8, 3]]], names: [:x, :y, :z])
    iex> Nx.argmin(t, axis: :y, keep_axis: true)
    #Nx.Tensor<
      s32[x: 2][y: 1][z: 3]
      [
        [
          [1, 1, 0]
        ],
        [
          [1, 0, 0]
        ]
      ]
    >

### Vectorized tensors

    iex> v = Nx.tensor([[1, 2, 3], [6, 5, 4]]) |> Nx.vectorize(:x)
    iex> Nx.argmin(v)
    #Nx.Tensor<
      vectorized[x: 2]
      s32
      [0, 2]
    >
    iex> Nx.argmin(v, axis: 0)
    #Nx.Tensor<
      vectorized[x: 2]
      s32
      [0, 2]
    >
    iex> Nx.argmin(v, keep_axis: true)
    #Nx.Tensor<
      vectorized[x: 2]
      s32[1]
      [
        [0],
        [2]
      ]
    >

## window_sum/3

Sums over each window of size `window_dimensions` in the
given tensor, producing a tensor that contains the same
number of elements as valid positions of the window.

You may optionally specify `:strides` which is a tuple
of non-zero steps to take along each axis between
each window.

You may also optionally specify `:padding` which is either
one of `:valid` (no padding) or `:same` (pad so output shape
is the same as input shape) or a general padding configuration
for each dimension in the input tensor. Your padding configuration
cannot include any negative pad values. You may only specify
padding for the high and low edges of the given dimension. Pads
with `0`.

## Examples

    iex> t = Nx.tensor([[[1, 2, 3], [4, 5, 6]], [[1, 2, 3], [4, 5, 6]]])
    iex> Nx.window_sum(t, {1, 2, 1})
    #Nx.Tensor<
      s32[2][1][3]
      [
        [
          [5, 7, 9]
        ],
        [
          [5, 7, 9]
        ]
      ]
    >

    iex> t = Nx.tensor([[[1, 2, 3], [4, 5, 6]], [[1, 2, 3], [4, 5, 6]]])
    iex> Nx.window_sum(t, {2, 2, 1}, strides: [1, 2, 3], padding: [{0, 1}, {2, 0}, {1, 1}])
    #Nx.Tensor<
      s32[2][2][2]
      [
        [
          [0, 0],
          [0, 18]
        ],
        [
          [0, 0],
          [0, 9]
        ]
      ]
    >

    iex> t = Nx.tensor([[[4.0, 2.0, 3.0], [2.0, 5.0, 6.5]], [[1.2, 2.2, 3.2], [4.0, 5.0, 6.2]]])
    iex> Nx.window_sum(t, {2, 1, 1}, strides: [2, 1, 1], padding: [{1, 1}, {0, 0}, {1, 1}])
    #Nx.Tensor<
      f32[2][2][5]
      [
        [
          [0.0, 4.0, 2.0, 3.0, 0.0],
          [0.0, 2.0, 5.0, 6.5, 0.0]
        ],
        [
          [0.0, 1.2, 2.2, 3.2, 0.0],
          [0.0, 4.0, 5.0, 6.2, 0.0]
        ]
      ]
    >

    iex> t = Nx.tensor([[[4, 2, 1, 3], [4, 2, 1, 7]], [[1, 2, 5, 7], [1, 8, 9, 2]]])
    iex> opts = [strides: [2, 1, 1], padding: :valid, window_dilations: [1, 2, 1]]
    iex> Nx.window_sum(t, {1, 1, 2}, opts)
    #Nx.Tensor<
      s32[1][2][3]
      [
        [
          [6, 3, 4],
          [6, 3, 8]
        ]
      ]
    >

    iex> t = Nx.tensor([[[4, 2, 1, 3], [4, 2, 1, 7]], [[1, 2, 5, 7], [1, 8, 9, 2]]])
    iex> opts = [strides: [2, 1, 1], padding: :valid, window_dilations: [1, 2, 2]]
    iex> Nx.window_sum(t, {1, 1, 2}, opts)
    #Nx.Tensor<
      s32[1][2][2]
      [
        [
          [5, 5],
          [5, 9]
        ]
      ]
    >

    iex> t = Nx.tensor([[[4, 2, 1, 3], [4, 2, 1, 7]], [[1, 2, 5, 7], [1, 8, 9, 2]]])
    iex> opts = [strides: [2, 1, 1], padding: [{2, 1}, {3, 1}, {1, 0}], window_dilations: [1, 2, 2]]
    iex> Nx.window_sum(t, {2, 1, 2}, opts)
    #Nx.Tensor<
      s32[2][6][3]
      [
        [
          [0, 0, 0],
          [0, 0, 0],
          [0, 0, 0],
          [0, 0, 0],
          [0, 0, 0],
          [0, 0, 0]
        ],
        [
          [0, 0, 0],
          [0, 0, 0],
          [0, 0, 0],
          [4, 11, 14],
          [10, 15, 19],
          [0, 0, 0]
        ]
      ]
    >

## Vectorized tensors

For vectorized tensors, the windows will slide throughout all vectorized axes,
and all options refer to the inner shape only.

    iex> t = Nx.iota({2, 1, 2, 5}) |> Nx.vectorize(:x) |> Nx.vectorize(:y)
    #Nx.Tensor<
      vectorized[x: 2][y: 1]
      s32[2][5]
      [
        [
          [
            [0, 1, 2, 3, 4],
            [5, 6, 7, 8, 9]
          ]
        ],
        [
          [
            [10, 11, 12, 13, 14],
            [15, 16, 17, 18, 19]
          ]
        ]
      ]
    >
    iex> Nx.window_sum(t, {2, 2}, strides: [1, 2], window_dilations: [1, 2])
    #Nx.Tensor<
      vectorized[x: 2][y: 1]
      s32[1][2]
      [
        [
          [
            [14, 22]
          ]
        ],
        [
          [
            [54, 62]
          ]
        ]
      ]
    >

## window_mean/3

Averages over each window of size `window_dimensions` in the
given tensor, producing a tensor that contains the same
number of elements as valid positions of the window.

You may optionally specify `:strides` which is a tuple
of non-zero steps to take along each axis between
each window.

You may also optionally specify `:padding` which is either
one of `:valid` (no padding) or `:same` (pad so output shape
is the same as input shape) or a general padding configuration
for each dimension in the input tensor. Your padding configuration
cannot include any negative pad values. You may only specify
padding for the high and low edges of the given dimension. Pads
with `0`.

## Examples

    iex> t = Nx.tensor([[[1, 2, 3], [4, 5, 6]], [[1, 2, 3], [4, 5, 6]]])
    iex> Nx.window_mean(t, {1, 2, 1})
    #Nx.Tensor<
      f32[2][1][3]
      [
        [
          [2.5, 3.5, 4.5]
        ],
        [
          [2.5, 3.5, 4.5]
        ]
      ]
    >

    iex> t = Nx.tensor([[[1, 2, 3], [4, 5, 6]], [[1, 2, 3], [4, 5, 6]]])
    iex> Nx.window_mean(t, {2, 2, 1}, strides: [1, 2, 3], padding: [{0, 1}, {2, 0}, {1, 1}])
    #Nx.Tensor<
      f32[2][2][2]
      [
        [
          [0.0, 0.0],
          [0.0, 4.5]
        ],
        [
          [0.0, 0.0],
          [0.0, 2.25]
        ]
      ]
    >

    iex> t = Nx.tensor([[[4.0, 2.0, 3.0], [2.0, 5.0, 6.5]], [[1.2, 2.2, 3.2], [4.0, 5.0, 6.2]]])
    iex> Nx.window_mean(t, {2, 1, 1}, strides: [2, 1, 1], padding: [{1, 1}, {0, 0}, {1, 1}])
    #Nx.Tensor<
      f32[2][2][5]
      [
        [
          [0.0, 2.0, 1.0, 1.5, 0.0],
          [0.0, 1.0, 2.5, 3.25, 0.0]
        ],
        [
          [0.0, 0.6, 1.1, 1.6, 0.0],
          [0.0, 2.0, 2.5, 3.1, 0.0]
        ]
      ]
    >

    iex> t = Nx.tensor([[[4, 2, 1, 3], [4, 2, 1, 7]], [[1, 2, 5, 7], [1, 8, 9, 2]]])
    iex> opts = [strides: [2, 1, 1], padding: :valid, window_dilations: [1, 2, 1]]
    iex> Nx.window_mean(t, {1, 1, 2}, opts)
    #Nx.Tensor<
      f32[1][2][3]
      [
        [
          [3.0, 1.5, 2.0],
          [3.0, 1.5, 4.0]
        ]
      ]
    >

    iex> t = Nx.tensor([[[4, 2, 1, 3], [4, 2, 1, 7]], [[1, 2, 5, 7], [1, 8, 9, 2]]])
    iex> opts = [strides: [2, 1, 1], padding: :valid, window_dilations: [1, 2, 2]]
    iex> Nx.window_mean(t, {1, 1, 2}, opts)
    #Nx.Tensor<
      f32[1][2][2]
      [
        [
          [2.5, 2.5],
          [2.5, 4.5]
        ]
      ]
    >

## Vectorized tensors

For vectorized tensors, the windows will slide throughout all vectorized axes,
and all options refer to the inner shape only.

    iex> t = Nx.iota({2, 1, 2, 5}) |> Nx.vectorize(:x) |> Nx.vectorize(:y)
    #Nx.Tensor<
      vectorized[x: 2][y: 1]
      s32[2][5]
      [
        [
          [
            [0, 1, 2, 3, 4],
            [5, 6, 7, 8, 9]
          ]
        ],
        [
          [
            [10, 11, 12, 13, 14],
            [15, 16, 17, 18, 19]
          ]
        ]
      ]
    >
    iex> Nx.window_mean(t, {2, 2}, strides: [1, 2], window_dilations: [1, 2])
    #Nx.Tensor<
      vectorized[x: 2][y: 1]
      f32[1][2]
      [
        [
          [
            [3.5, 5.5]
          ]
        ],
        [
          [
            [13.5, 15.5]
          ]
        ]
      ]
    >

## window_max/3

Returns the maximum over each window of size `window_dimensions`
in the given tensor, producing a tensor that contains the same
number of elements as valid positions of the window.

You may optionally specify `:strides` which is a tuple
of non-zero steps to take along each axis between
each window.

You may also optionally specify `:padding` which is either
one of `:valid` (no padding) or `:same` (pad so output shape
is the same as input shape) or a general padding configuration
for each dimension in the input tensor. Your padding configuration
cannot include any negative pad values. You may only specify
padding for the high and low edges of the given dimension. Pads
with the minimum value for the type of the given tensor.

## Examples

    iex> Nx.window_max(Nx.tensor([[[1, 2, 3], [4, 5, 6]], [[1, 2, 3], [4, 5, 6]]]), {1, 2, 1})
    #Nx.Tensor<
      s32[2][1][3]
      [
        [
          [4, 5, 6]
        ],
        [
          [4, 5, 6]
        ]
      ]
    >

    iex> t = Nx.tensor([[[1, 2, 3], [4, 5, 6]], [[1, 2, 3], [4, 5, 6]]])
    iex> Nx.window_max(t, {2, 2, 1}, strides: [1, 2, 3], padding: [{0, 1}, {2, 0}, {1, 1}])
    #Nx.Tensor<
      s32[2][2][2]
      [
        [
          [-2147483648, -2147483648],
          [-2147483648, 6]
        ],
        [
          [-2147483648, -2147483648],
          [-2147483648, 6]
        ]
      ]
    >

    iex> t = Nx.tensor([[[4.0, 2.0, 3.0], [2.0, 5.0, 6.5]], [[1.2, 2.2, 3.2], [4.0, 5.0, 6.2]]])
    iex> Nx.window_max(t, {2, 1, 1}, strides: [2, 1, 1], padding: [{1, 1}, {0, 0}, {1, 1}])
    #Nx.Tensor<
      f32[2][2][5]
      [
        [
          [-Inf, 4.0, 2.0, 3.0, -Inf],
          [-Inf, 2.0, 5.0, 6.5, -Inf]
        ],
        [
          [-Inf, 1.2, 2.2, 3.2, -Inf],
          [-Inf, 4.0, 5.0, 6.2, -Inf]
        ]
      ]
    >

    iex> t = Nx.tensor([[[4, 2, 1, 3], [4, 2, 1, 7]], [[1, 2, 5, 7], [1, 8, 9, 2]]])
    iex> opts = [strides: [2, 1, 1], padding: :valid, window_dilations: [1, 2, 2]]
    iex> Nx.window_max(t, {1, 1, 2}, opts)
    #Nx.Tensor<
      s32[1][2][2]
      [
        [
          [4, 3],
          [4, 7]
        ]
      ]
    >

## Vectorized tensors

For vectorized tensors, the windows will slide throughout all vectorized axes,
and all options refer to the inner shape only.

    iex> t = Nx.iota({2, 1, 2, 5}) |> Nx.vectorize(:x) |> Nx.vectorize(:y)
    #Nx.Tensor<
      vectorized[x: 2][y: 1]
      s32[2][5]
      [
        [
          [
            [0, 1, 2, 3, 4],
            [5, 6, 7, 8, 9]
          ]
        ],
        [
          [
            [10, 11, 12, 13, 14],
            [15, 16, 17, 18, 19]
          ]
        ]
      ]
    >
    iex> Nx.window_max(t, {2, 2}, strides: [1, 2], window_dilations: [1, 2])
    #Nx.Tensor<
      vectorized[x: 2][y: 1]
      s32[1][2]
      [
        [
          [
            [7, 9]
          ]
        ],
        [
          [
            [17, 19]
          ]
        ]
      ]
    >

## window_min/3

Returns the minimum over each window of size `window_dimensions`
in the given tensor, producing a tensor that contains the same
number of elements as valid positions of the window.

You may optionally specify `:strides` which is a tuple
of non-zero steps to take along each axis between
each window.

You may also optionally specify `:padding` which is either
one of `:valid` (no padding) or `:same` (pad so output shape
is the same as input shape) or a general padding configuration
for each dimension in the input tensor. Your padding configuration
cannot include any negative pad values. You may only specify
padding for the high and low edges of the given dimension. Pads
with the maximum value for the type of the given tensor.

## Examples

    iex> Nx.window_min(Nx.tensor([[[1, 2, 3], [4, 5, 6]], [[1, 2, 3], [4, 5, 6]]]), {1, 2, 1})
    #Nx.Tensor<
      s32[2][1][3]
      [
        [
          [1, 2, 3]
        ],
        [
          [1, 2, 3]
        ]
      ]
    >

    iex> t = Nx.tensor([[[1, 2, 3], [4, 5, 6]], [[1, 2, 3], [4, 5, 6]]])
    iex> Nx.window_min(t, {2, 2, 1}, strides: [1, 2, 3], padding: [{0, 1}, {2, 0}, {1, 1}])
    #Nx.Tensor<
      s32[2][2][2]
      [
        [
          [2147483647, 2147483647],
          [2147483647, 3]
        ],
        [
          [2147483647, 2147483647],
          [2147483647, 3]
        ]
      ]
    >

    iex> t = Nx.tensor([[[4.0, 2.0, 3.0], [2.0, 5.0, 6.5]], [[1.2, 2.2, 3.2], [4.0, 5.0, 6.2]]])
    iex> Nx.window_min(t, {2, 1, 1}, strides: [2, 1, 1], padding: [{1, 1}, {0, 0}, {1, 1}])
    #Nx.Tensor<
      f32[2][2][5]
      [
        [
          [Inf, 4.0, 2.0, 3.0, Inf],
          [Inf, 2.0, 5.0, 6.5, Inf]
        ],
        [
          [Inf, 1.2, 2.2, 3.2, Inf],
          [Inf, 4.0, 5.0, 6.2, Inf]
        ]
      ]
    >

    iex> t = Nx.tensor([[[4, 2, 1, 3], [4, 2, 1, 7]], [[1, 2, 5, 7], [1, 8, 9, 2]]])
    iex> opts = [strides: [2, 1, 1], padding: :valid, window_dilations: [1, 2, 2]]
    iex> Nx.window_min(t, {1, 1, 2}, opts)
    #Nx.Tensor<
      s32[1][2][2]
      [
        [
          [1, 2],
          [1, 2]
        ]
      ]
    >

## Vectorized tensors

For vectorized tensors, the windows will slide throughout all vectorized axes,
and all options refer to the inner shape only.

    iex> t = Nx.iota({2, 1, 2, 5}) |> Nx.vectorize(:x) |> Nx.vectorize(:y)
    #Nx.Tensor<
      vectorized[x: 2][y: 1]
      s32[2][5]
      [
        [
          [
            [0, 1, 2, 3, 4],
            [5, 6, 7, 8, 9]
          ]
        ],
        [
          [
            [10, 11, 12, 13, 14],
            [15, 16, 17, 18, 19]
          ]
        ]
      ]
    >
    iex> Nx.window_min(t, {2, 2}, strides: [1, 2], window_dilations: [1, 2])
    #Nx.Tensor<
      vectorized[x: 2][y: 1]
      s32[1][2]
      [
        [
          [
            [0, 2]
          ]
        ],
        [
          [
            [10, 12]
          ]
        ]
      ]
    >

## window_product/3

Returns the product over each window of size `window_dimensions`
in the given tensor, producing a tensor that contains the same
number of elements as valid positions of the window.

The rank of the input tensor and the window dimensions must
match.

You may optionally specify `:strides` which is a tuple
of non-zero steps to take along each axis between
each window.

You may also optionally specify `:padding` which is either
one of `:valid` (no padding) or `:same` (pad so output shape
is the same as input shape) or a general padding configuration
for each dimension in the input tensor. Your padding configuration
cannot include any negative pad values. You may only specify
padding for the high and low edges of the given dimension. Pads
with 1.

## Examples

    iex> Nx.window_product(Nx.tensor([[[1, 2, 3], [4, 5, 6]], [[1, 2, 3], [4, 5, 6]]]), {1, 2, 1})
    #Nx.Tensor<
      s32[2][1][3]
      [
        [
          [4, 10, 18]
        ],
        [
          [4, 10, 18]
        ]
      ]
    >

    iex> t = Nx.tensor([[[1, 2, 3], [4, 5, 6]], [[1, 2, 3], [4, 5, 6]]])
    iex> Nx.window_product(t, {2, 2, 1}, strides: [1, 2, 3], padding: [{0, 1}, {2, 0}, {1, 1}])
    #Nx.Tensor<
      s32[2][2][2]
      [
        [
          [1, 1],
          [1, 324]
        ],
        [
          [1, 1],
          [1, 18]
        ]
      ]
    >

    iex> t = Nx.tensor([[[4.0, 2.0, 3.0], [2.0, 5.0, 6.5]], [[1.2, 2.2, 3.2], [4.0, 5.0, 6.2]]])
    iex> Nx.window_product(t, {2, 1, 1}, strides: [2, 1, 1], padding: [{1, 1}, {0, 0}, {1, 1}])
    #Nx.Tensor<
      f32[2][2][5]
      [
        [
          [1.0, 4.0, 2.0, 3.0, 1.0],
          [1.0, 2.0, 5.0, 6.5, 1.0]
        ],
        [
          [1.0, 1.2, 2.2, 3.2, 1.0],
          [1.0, 4.0, 5.0, 6.2, 1.0]
        ]
      ]
    >

    iex> t = Nx.tensor([[[4, 2, 1, 3], [4, 2, 1, 7]], [[1, 2, 5, 7], [1, 8, 9, 2]]])
    iex> opts = [strides: [2, 1, 1], padding: :valid, window_dilations: [1, 2, 2]]
    iex> Nx.window_product(t, {1, 1, 2}, opts)
    #Nx.Tensor<
      s32[1][2][2]
      [
        [
          [4, 6],
          [4, 14]
        ]
      ]
    >

## Vectorized tensors

For vectorized tensors, the windows will slide throughout all vectorized axes,
and all options refer to the inner shape only.

    iex> t = Nx.iota({2, 1, 2, 5}) |> Nx.vectorize(:x) |> Nx.vectorize(:y)
    #Nx.Tensor<
      vectorized[x: 2][y: 1]
      s32[2][5]
      [
        [
          [
            [0, 1, 2, 3, 4],
            [5, 6, 7, 8, 9]
          ]
        ],
        [
          [
            [10, 11, 12, 13, 14],
            [15, 16, 17, 18, 19]
          ]
        ]
      ]
    >
    iex> Nx.window_product(t, {2, 2}, strides: [1, 2], window_dilations: [1, 2])
    #Nx.Tensor<
      vectorized[x: 2][y: 1]
      s32[1][2]
      [
        [
          [
            [0, 504]
          ]
        ],
        [
          [
            [30600, 54264]
          ]
        ]
      ]
    >

## cumulative_sum/2

Returns the cumulative sum of elements along an axis.

## Options

  * `:axis` - the axis to sum elements along. Defaults to `0`
  * `:reverse` - whether to perform accumulation in the opposite direction. Defaults to `false`

## Examples

    iex> Nx.cumulative_sum(Nx.tensor([1, 2, 3, 4]))
    #Nx.Tensor<
      s32[4]
      [1, 3, 6, 10]
    >

    iex> Nx.cumulative_sum(Nx.iota({3, 3}), axis: 0)
    #Nx.Tensor<
      s32[3][3]
      [
        [0, 1, 2],
        [3, 5, 7],
        [9, 12, 15]
      ]
    >

    iex> Nx.cumulative_sum(Nx.iota({3, 3}), axis: 1)
    #Nx.Tensor<
      s32[3][3]
      [
        [0, 1, 3],
        [3, 7, 12],
        [6, 13, 21]
      ]
    >

    iex> Nx.cumulative_sum(Nx.iota({3, 3}), axis: 0, reverse: true)
    #Nx.Tensor<
      s32[3][3]
      [
        [9, 12, 15],
        [9, 11, 13],
        [6, 7, 8]
      ]
    >

    iex> Nx.cumulative_sum(Nx.iota({3, 3}), axis: 1, reverse: true)
    #Nx.Tensor<
      s32[3][3]
      [
        [3, 3, 2],
        [12, 9, 5],
        [21, 15, 8]
      ]
    >

## Vectorized axes

Works the same as if the accumulation was to happen over a list of tensors.
`:axis` refers to the non-vectorized shape.

    iex> Nx.cumulative_sum(Nx.tensor([[2, 3, 1], [1, 3, 2], [2, 1, 3]]) |> Nx.vectorize(:x), axis: 0)
    #Nx.Tensor<
      vectorized[x: 3]
      s32[3]
      [
        [2, 5, 6],
        [1, 4, 6],
        [2, 3, 6]
      ]
    >

## cumulative_product/2

Returns the cumulative product of elements along an axis.

## Options

  * `:axis` - the axis to multiply elements along. Defaults to `0`
  * `:reverse` - whether to perform accumulation in the opposite direction. Defaults to `false`

## Examples

    iex> Nx.cumulative_product(Nx.tensor([1, 2, 3, 4]))
    #Nx.Tensor<
      s32[4]
      [1, 2, 6, 24]
    >

    iex> Nx.cumulative_product(Nx.iota({3, 3}), axis: 0)
    #Nx.Tensor<
      s32[3][3]
      [
        [0, 1, 2],
        [0, 4, 10],
        [0, 28, 80]
      ]
    >

    iex> Nx.cumulative_product(Nx.iota({3, 3}), axis: 1)
    #Nx.Tensor<
      s32[3][3]
      [
        [0, 0, 0],
        [3, 12, 60],
        [6, 42, 336]
      ]
    >

    iex> Nx.cumulative_product(Nx.iota({3, 3}), axis: 0, reverse: true)
    #Nx.Tensor<
      s32[3][3]
      [
        [0, 28, 80],
        [18, 28, 40],
        [6, 7, 8]
      ]
    >

    iex> Nx.cumulative_product(Nx.iota({3, 3}), axis: 1, reverse: true)
    #Nx.Tensor<
      s32[3][3]
      [
        [0, 2, 2],
        [60, 20, 5],
        [336, 56, 8]
      ]
    >

## Vectorized axes

Works the same as if the accumulation was to happen over a list of tensors.
`:axis` refers to the non-vectorized shape.

    iex> Nx.cumulative_product(Nx.tensor([[2, 3, 0], [1, 3, 2], [2, 1, 3]]) |> Nx.vectorize(:x), axis: 0)
    #Nx.Tensor<
      vectorized[x: 3]
      s32[3]
      [
        [2, 6, 0],
        [1, 3, 6],
        [2, 2, 6]
      ]
    >

## cumulative_min/2

Returns the cumulative minimum of elements along an axis.

## Options

  * `:axis` - the axis to compare elements along. Defaults to `0`
  * `:reverse` - whether to perform accumulation in the opposite direction. Defaults to `false`

## Examples

    iex> Nx.cumulative_min(Nx.tensor([3, 4, 2, 1]))
    #Nx.Tensor<
      s32[4]
      [3, 3, 2, 1]
    >

    iex> Nx.cumulative_min(Nx.tensor([[2, 3, 1], [1, 3, 2], [2, 1, 3]]), axis: 0)
    #Nx.Tensor<
      s32[3][3]
      [
        [2, 3, 1],
        [1, 3, 1],
        [1, 1, 1]
      ]
    >

    iex> Nx.cumulative_min(Nx.tensor([[2, 3, 1], [1, 3, 2], [2, 1, 3]]), axis: 1)
    #Nx.Tensor<
      s32[3][3]
      [
        [2, 2, 1],
        [1, 1, 1],
        [2, 1, 1]
      ]
    >

    iex> Nx.cumulative_min(Nx.tensor([[2, 3, 1], [1, 3, 2], [2, 1, 3]]), axis: 0, reverse: true)
    #Nx.Tensor<
      s32[3][3]
      [
        [1, 1, 1],
        [1, 1, 2],
        [2, 1, 3]
      ]
    >

    iex> Nx.cumulative_min(Nx.tensor([[2, 3, 1], [1, 3, 2], [2, 1, 3]]), axis: 1, reverse: true)
    #Nx.Tensor<
      s32[3][3]
      [
        [1, 1, 1],
        [1, 2, 2],
        [1, 1, 3]
      ]
    >

## Vectorized axes

Works the same as if the accumulation was to happen over a list of tensors.
`:axis` refers to the non-vectorized shape.

    iex> Nx.cumulative_min(Nx.tensor([[2, 3, 1], [1, 3, 2], [2, 1, 3]]) |> Nx.vectorize(:x), axis: 0)
    #Nx.Tensor<
      vectorized[x: 3]
      s32[3]
      [
        [2, 2, 1],
        [1, 1, 1],
        [2, 1, 1]
      ]
    >

## cumulative_max/2

Returns the cumulative maximum of elements along an axis.

## Options

  * `:axis` - the axis to compare elements along. Defaults to `0`
  * `:reverse` - whether to perform accumulation in the opposite direction. Defaults to `false`

## Examples

    iex> Nx.cumulative_max(Nx.tensor([3, 4, 2, 1]))
    #Nx.Tensor<
      s32[4]
      [3, 4, 4, 4]
    >

    iex> Nx.cumulative_max(Nx.tensor([[2, 3, 1], [1, 3, 2], [2, 1, 3]]), axis: 0)
    #Nx.Tensor<
      s32[3][3]
      [
        [2, 3, 1],
        [2, 3, 2],
        [2, 3, 3]
      ]
    >

    iex> Nx.cumulative_max(Nx.tensor([[2, 3, 1], [1, 3, 2], [2, 1, 3]]), axis: 1)
    #Nx.Tensor<
      s32[3][3]
      [
        [2, 3, 3],
        [1, 3, 3],
        [2, 2, 3]
      ]
    >

    iex> Nx.cumulative_max(Nx.tensor([[2, 3, 1], [1, 3, 2], [2, 1, 3]]), axis: 0, reverse: true)
    #Nx.Tensor<
      s32[3][3]
      [
        [2, 3, 3],
        [2, 3, 3],
        [2, 1, 3]
      ]
    >

    iex> Nx.cumulative_max(Nx.tensor([[2, 3, 1], [1, 3, 2], [2, 1, 3]]), axis: 1, reverse: true)
    #Nx.Tensor<
      s32[3][3]
      [
        [3, 3, 1],
        [3, 3, 2],
        [3, 3, 3]
      ]
    >

## Vectorized axes

Works the same as if the accumulation was to happen over a list of tensors.
`:axis` refers to the non-vectorized shape.

    iex> Nx.cumulative_max(Nx.tensor([[2, 3, 1], [1, 3, 2], [2, 1, 3]]) |> Nx.vectorize(:x), axis: 0)
    #Nx.Tensor<
      vectorized[x: 3]
      s32[3]
      [
        [2, 3, 3],
        [1, 3, 3],
        [2, 2, 3]
      ]
    >

## diff/2

Calculate the n-th discrete difference along the given axis.

The first difference is given by $out_i = a_{i+1} - a_i$ along the given axis,
higher differences are calculated by using `diff` recursively.

## Options

  * `:order` - the number of times to perform the difference. Defaults to `1`
  * `:axis` - the axis to perform the difference along. Defaults to `-1`

## Examples

    iex> Nx.diff(Nx.tensor([1, 2, 4, 7, 0]))
    #Nx.Tensor<
      s32[4]
      [1, 2, 3, -7]
    >

    iex> Nx.diff(Nx.tensor([1, 2, 4, 7, 0]), order: 2)
    #Nx.Tensor<
      s32[3]
      [1, 1, -10]
    >

    iex> Nx.diff(Nx.tensor([[1, 3, 6, 10], [0, 5, 6, 8]]))
    #Nx.Tensor<
      s32[2][3]
      [
        [2, 3, 4],
        [5, 1, 2]
      ]
    >

    iex> Nx.diff(Nx.tensor([[1, 3, 6, 10], [0, 5, 6, 8]]), axis: 0)
    #Nx.Tensor<
      s32[1][4]
      [
        [-1, 2, 0, -2]
      ]
    >

    iex> Nx.diff(Nx.tensor([1, 2, 4, 7, 0]), order: 0)
    #Nx.Tensor<
      s32[5]
      [1, 2, 4, 7, 0]
    >

    iex> Nx.diff(Nx.tensor([1, 2, 4, 7, 0]), order: -1)
    ** (ArgumentError) order must be non-negative but got: -1

## reduce/4

Reduces over a tensor with the given accumulator.

The given `fun` will receive two tensors and it must
return the reduced value.

The tensor may be reduced in parallel and the reducer
function can be called with arguments in any order, the
initial accumulator may be given multiples, and it may
be non-deterministic. Therefore, the reduction function
should be associative (or as close as possible to
associativity considered floats themselves are not
strictly associative).

By default, it reduces all dimensions of the tensor and
return a scalar. If the `:axes` option is given, it
aggregates over multiple dimensions, effectively removing
them. `axes: [0]` implies aggregating over the highest
order dimension and so forth. If the axis is negative,
then counts the axis from the back. For example,
`axes: [-1]` will always aggregate all rows.

The type of the returned tensor will be computed based on
the given tensor and the initial value. For example,
a tensor of integers with a float accumulator will be
cast to float, as done by most binary operators. You can
also pass a `:type` option to change this behaviour.

You may optionally set `:keep_axes` to true, which will
retain the rank of the input tensor by setting the reduced
axes to size 1.

## Limitations

Given this function relies on anonymous functions, it
may not be available or efficient on all Nx backends.
Therefore, you should avoid using `reduce/4` whenever
possible. Instead, use functions `sum/2`, `reduce_max/2`,
`all/1`, and so forth.

Inside `defn`, consider using `Nx.Defn.Kernel.while/4` instead.

## Examples

    iex> Nx.reduce(Nx.tensor(42), 0, fn x, y -> Nx.add(x, y) end)
    #Nx.Tensor<
      s32
      42
    >

    iex> Nx.reduce(Nx.tensor([1, 2, 3]), 0, fn x, y -> Nx.add(x, y) end)
    #Nx.Tensor<
      s32
      6
    >

    iex> Nx.reduce(Nx.tensor([[1.0, 2.0], [3.0, 4.0]]), 0, fn x, y -> Nx.add(x, y) end)
    #Nx.Tensor<
      f32
      10.0
    >

### Aggregating over axes

    iex> t = Nx.tensor([1, 2, 3], names: [:x])
    iex> Nx.reduce(t, 0, [axes: [:x]], fn x, y -> Nx.add(x, y) end)
    #Nx.Tensor<
      s32
      6
    >

    iex> t = Nx.tensor([[[1, 2, 3], [4, 5, 6]], [[7, 8, 9], [10, 11, 12]]], names: [:x, :y, :z])
    iex> Nx.reduce(t, 0, [axes: [:x]], fn x, y -> Nx.add(x, y) end)
    #Nx.Tensor<
      s32[y: 2][z: 3]
      [
        [8, 10, 12],
        [14, 16, 18]
      ]
    >

    iex> t = Nx.tensor([[[1, 2, 3], [4, 5, 6]], [[7, 8, 9], [10, 11, 12]]], names: [:x, :y, :z])
    iex> Nx.reduce(t, 0, [axes: [:y]], fn x, y -> Nx.add(x, y) end)
    #Nx.Tensor<
      s32[x: 2][z: 3]
      [
        [5, 7, 9],
        [17, 19, 21]
      ]
    >

    iex> t = Nx.tensor([[[1, 2, 3], [4, 5, 6]], [[7, 8, 9], [10, 11, 12]]], names: [:x, :y, :z])
    iex> Nx.reduce(t, 0, [axes: [:x, 2]], fn x, y -> Nx.add(x, y) end)
    #Nx.Tensor<
      s32[y: 2]
      [30, 48]
    >

    iex> t = Nx.tensor([[[1, 2, 3], [4, 5, 6]], [[7, 8, 9], [10, 11, 12]]], names: [:x, :y, :z])
    iex> Nx.reduce(t, 0, [axes: [-1]], fn x, y -> Nx.add(x, y) end)
    #Nx.Tensor<
      s32[x: 2][y: 2]
      [
        [6, 15],
        [24, 33]
      ]
    >

    iex> t = Nx.tensor([[[1, 2, 3], [4, 5, 6]], [[7, 8, 9], [10, 11, 12]]], names: [:x, :y, :z])
    iex> Nx.reduce(t, 0, [axes: [:x]], fn x, y -> Nx.add(x, y) end)
    #Nx.Tensor<
      s32[y: 2][z: 3]
      [
        [8, 10, 12],
        [14, 16, 18]
      ]
    >

    iex> t = Nx.tensor([[[1, 2, 3], [4, 5, 6]], [[7, 8, 9], [10, 11, 12]]], names: [:x, :y, :z])
    iex> Nx.reduce(t, 0, [axes: [:x], keep_axes: true], fn x, y -> Nx.add(x, y) end)
    #Nx.Tensor<
      s32[x: 1][y: 2][z: 3]
      [
        [
          [8, 10, 12],
          [14, 16, 18]
        ]
      ]
    >

## Vectorized tensors

Only `tensor` can be vectorized. Normal behavior of `reduce/4`
is applied to each corresponding entry. `:axes` refers to the
non-vectorized shape.

    iex> t = Nx.tensor([[[1, 2, 3], [4, 5, 6]], [[10, 20, 30], [40, 50, 60]]]) |> Nx.vectorize(:x)
    iex> Nx.reduce(t, 10, [axes: [1]], &Nx.add/2)
    #Nx.Tensor<
      vectorized[x: 2]
      s32[2]
      [
        [16, 25],
        [70, 160]
      ]
    >

## window_reduce/5

Reduces over each window of size `dimensions`
in the given tensor, producing a tensor that contains the same
number of elements as valid positions of the window.

The rank of the input tensor and the window dimensions must
match.

You may optionally specify `:strides` which is a tuple
of non-zero steps to take along each axis between
each window.

You may also optionally specify `:padding` which is either
one of `:valid` (no padding) or `:same` (pad so output shape
is the same as input shape) or a general padding configuration
for each dimension in the input tensor. Your padding configuration
cannot include any negative pad values. You may only specify
padding for the high and low edges of the given dimension. The
padding value is equal to the initial value passed to `acc`.

The initial value must be a number or a scalar shaped tensor.

## Examples

    iex> init_value = Nx.Constants.min_finite(:s32)
    iex> t = Nx.tensor([[1, 2, 3, 4], [4, 5, 6, 7], [7, 8, 9, 10], [11, 12, 13, 14]])
    iex> Nx.window_reduce(t, init_value, {2, 2}, fn x, acc -> Nx.max(x, acc) end)
    #Nx.Tensor<
      s32[3][3]
      [
        [5, 6, 7],
        [8, 9, 10],
        [12, 13, 14]
      ]
    >

    iex> init_value = Nx.Constants.min_finite(:s32)
    iex> t = Nx.tensor([[1, 2, 3], [4, 5, 6], [7, 8, 9]])
    iex> opts = [padding: :same, strides: [1, 1]]
    iex> Nx.window_reduce(t, init_value, {2, 2}, opts, fn x, acc -> Nx.max(x, acc) end)
    #Nx.Tensor<
      s32[3][3]
      [
        [5, 6, 6],
        [8, 9, 9],
        [8, 9, 9]
      ]
    >

    iex> t = Nx.tensor([[1, 2, 3], [4, 5, 6]])
    iex> opts = [padding: :same, strides: [1, 1]]
    iex> Nx.window_reduce(t, 0, {1, 2}, opts, fn x, acc -> Nx.add(x, acc) end)
    #Nx.Tensor<
      s32[2][3]
      [
        [3, 5, 3],
        [9, 11, 6]
      ]
    >

    iex> t = Nx.tensor([[[4, 2, 1, 3], [4, 2, 1, 7]], [[1, 2, 5, 7], [1, 8, 9, 2]]])
    iex> opts = [padding: :valid, strides: [2, 1, 1], window_dilations: [1, 1, 2]]
    iex> Nx.window_reduce(t, 0, {1, 1, 2}, opts, fn x, acc -> Nx.add(x, acc) end)
    #Nx.Tensor<
      s32[1][2][2]
      [
        [
          [5, 5],
          [5, 9]
        ]
      ]
    >

## Vectorized tensors

The accumulator must not be vectorized. Aside from that, `window_reduce` will apply the reduction
over each non-vectorized entry, as follows:

    iex> t = Nx.tensor([[[1, 2, 3], [4, 5, 6]], [[0, -1, -2], [-3, -4, -5]]]) |> Nx.vectorize(x: 2)
    iex> opts = [padding: [{0, 0}, {0, 1}], strides: [1, 1]]
    iex> Nx.window_reduce(t, 0, {2, 2}, opts, fn x, acc -> Nx.add(x, acc) end)
    #Nx.Tensor<
      vectorized[x: 2]
      s32[1][3]
      [
        [
          [12, 16, 9]
        ],
        [
          [-8, -12, -7]
        ]
      ]
    >

## dot/2

Returns the dot product of two tensors.

Given `a` and `b`, computes the dot product according to
the following rules:

  * If both `a` and `b` are scalars, it is equivalent to `a * b`.

  * If `a` is a scalar and `b` is a tensor, it is equivalent to `Nx.multiply(a, b)`.

  * If `a` is a tensor and `b` is a scalar, it is equivalent to `Nx.multiply(a, b)`.

  * If both `a` and `b` are 1-D tensors (vectors), it is the sum of the element-wise
    product between `a` and `b`. The lengths of `a` and `b` must be equal.

  * If both `a` and `b` are 2-D tensors (matrices), it is equivalent to matrix-multiplication.

  * If either `a` or `b` is a 1-D tensor, and the other is an n-D tensor, it is the
    sum of the element-wise product along the last axis of `a` or `b`. The length of the
    1-D tensor must match the last dimension of the n-D tensor.

  * If `a` is an n-D tensor and `b` is an m-D tensor, it is the sum of the element-wise
    product along the last axis of `a` and the second-to-last axis of `b`. The last dimension
    of `a` must match the second-to-last dimension of `b`.

For a more general `dot` function where you control which axes contract,
see `dot/4`.

## Examples

### Dot product of scalars

    iex> Nx.dot(5, 5)
    #Nx.Tensor<
      s32
      25
    >

    iex> Nx.dot(-2.0, 5.0)
    #Nx.Tensor<
      f32
      -10.0
    >

    iex> Nx.dot(2, 2.0)
    #Nx.Tensor<
      f32
      4.0
    >

### Dot product of vectors

    iex> Nx.dot(Nx.tensor([1, 2, 3]), Nx.tensor([4, 5, 6]))
    #Nx.Tensor<
      s32
      32
    >

    iex> Nx.dot(Nx.tensor([2.0, 4.0, 3.0, 5.0]), Nx.tensor([1.0, 2.0, 3.0, 4.0]))
    #Nx.Tensor<
      f32
      39.0
    >

    iex> Nx.dot(Nx.tensor([1.0, 2.0, 3.0]), Nx.tensor([1, 2, 3]))
    #Nx.Tensor<
      f32
      14.0
    >

### Dot product of matrices

    iex> left = Nx.tensor([[1, 2, 3], [4, 5, 6]], names: [:i, :j])
    iex> right = Nx.tensor([[7, 8], [9, 10], [11, 12]], names: [:x, :y])
    iex> Nx.dot(left, right)
    #Nx.Tensor<
      s32[i: 2][y: 2]
      [
        [58, 64],
        [139, 154]
      ]
    >

    iex> left = Nx.tensor([[10.0, 13.0, 14.0, 15.0], [59.0, 20.0, 10.0, 30.0]], names: [:i, :j])
    iex> right = Nx.tensor([[2.0, 4.0], [5.0, 1.0], [6.0, 8.0], [9.0, 10.0]], names: [:x, :y])
    iex> Nx.dot(left, right)
    #Nx.Tensor<
      f32[i: 2][y: 2]
      [
        [304.0, 315.0],
        [548.0, 636.0]
      ]
    >

    iex> left = Nx.tensor([[1, 2, 3], [4, 5, 6]], names: [:i, :j])
    iex> right = Nx.tensor([[7.0, 8.0], [9.0, 10.0], [11.0, 12.0]], names: [:x, :y])
    iex> Nx.dot(left, right)
    #Nx.Tensor<
      f32[i: 2][y: 2]
      [
        [58.0, 64.0],
        [139.0, 154.0]
      ]
    >

### Dot product of vector and n-d tensor

    iex> left = Nx.tensor([[[1, 2], [3, 4]], [[5, 6], [7, 8]]], names: [:i, :j, :k])
    iex> right = Nx.tensor([5, 10], names: [:x])
    iex> Nx.dot(left, right)
    #Nx.Tensor<
      s32[i: 2][j: 2]
      [
        [25, 55],
        [85, 115]
      ]
    >

    iex> left = Nx.tensor([5, 10], names: [:x])
    iex> right = Nx.tensor([[1, 2, 3], [4, 5, 6]], names: [:i, :j])
    iex> Nx.dot(left, right)
    #Nx.Tensor<
      s32[j: 3]
      [45, 60, 75]
    >

    iex> left = Nx.tensor([[[[[1.0, 2.0], [3.0, 4.0]], [[5.0, 6.0], [7.0, 8.0]]]]], names: [:shard, :batch, :x, :y, :z])
    iex> right = Nx.tensor([2.0, 2.0], names: [:data])
    iex> Nx.dot(left, right)
    #Nx.Tensor<
      f32[shard: 1][batch: 1][x: 2][y: 2]
      [
        [
          [
            [6.0, 14.0],
            [22.0, 30.0]
          ]
        ]
      ]
    >

### Dot product of n-D and m-D tensor

    iex> left = Nx.tensor([[[1, 2, 3], [4, 5, 6], [7, 8, 9]], [[1, 2, 3], [4, 5, 6], [7, 8, 9]]], names: [:x, :y, :z])
    iex> right = Nx.tensor([[[1, 2, 3], [3, 4, 5], [5, 6, 7]]], names: [:i, :j, :k])
    iex> Nx.dot(left, right)
    #Nx.Tensor<
      s32[x: 2][y: 3][i: 1][k: 3]
      [
        [
          [
            [22, 28, 34]
          ],
          [
            [49, 64, 79]
          ],
          [
            [76, 100, 124]
          ]
        ],
        [
          [
            [22, 28, 34]
          ],
          [
            [49, 64, 79]
          ],
          [
            [76, 100, 124]
          ]
        ]
      ]
    >

## Vectorized tensors

Vectorized axes are treated as batched axes, much like
`dot/6` behaves with non-vectorized tensors.

    iex> t1 = Nx.tensor([[1, 2], [3, 4]]) |> Nx.vectorize(:x)
    iex> t2 = Nx.tensor([[10, 20], [30, 40]]) |> Nx.vectorize(:x)
    iex> Nx.dot(t1, t2)
    #Nx.Tensor<
      vectorized[x: 2]
      s32
      [50, 250]
    >

    iex> t1 = Nx.tensor([1, 2]) |> Nx.vectorize(:x)
    iex> t2 = Nx.tensor([[10, 20]]) |> Nx.vectorize(:y)
    iex> Nx.dot(t1, t2)
    #Nx.Tensor<
      vectorized[x: 2][y: 1]
      s32[2]
      [
        [
          [10, 20]
        ],
        [
          [20, 40]
        ]
      ]
    >


## Error cases

    iex> Nx.dot(Nx.tensor([1, 2, 3]), Nx.tensor([1, 2]))
    ** (ArgumentError) dot/zip expects shapes to be compatible, dimension 0 of left-side (3) does not equal dimension 0 of right-side (2)

## dot/4

Computes the generalized dot product between two tensors, given
the contracting axes.

This is equivalent to calling `Nx.dot/6` with no batching dimensions:

    Nx.dot(t1, contract_axes1, [], t2, contract_axes2, [])

## Examples

    iex> t1 = Nx.tensor([[1, 2], [3, 4]], names: [:x, :y])
    iex> t2 = Nx.tensor([[10, 20], [30, 40]], names: [:height, :width])
    iex> Nx.dot(t1, [0], t2, [0])
    #Nx.Tensor<
      s32[y: 2][width: 2]
      [
        [100, 140],
        [140, 200]
      ]
    >

    iex> t1 = Nx.tensor([[0.0, 1.0, 2.0], [3.0, 4.0, 5.0]])
    iex> t2 = Nx.tensor([[0.0, 1.0], [2.0, 3.0], [4.0, 5.0]])
    iex> Nx.dot(t1, [0, 1], t2, [1, 0])
    #Nx.Tensor<
      f32
      50.0
    >

## Vectorized tensors

The contracting axes refer to the tensors' shapes
and do not apply to the vectorized axes:

    iex> t1 = Nx.tensor([[[1, 1], [2, 2]], [[1, 1], [1, 1]]]) |> Nx.vectorize(:x)
    iex> t2 = Nx.tensor([[1, 2], [3, 4]])
    iex> Nx.dot(t1, [0], t2, [0])
    #Nx.Tensor<
      vectorized[x: 2]
      s32[2][2]
      [
        [
          [7, 10],
          [7, 10]
        ],
        [
          [4, 6],
          [4, 6]
        ]
      ]
    >
    iex> Nx.dot(t1, [1], t2, [0])
    #Nx.Tensor<
      vectorized[x: 2]
      s32[2][2]
      [
        [
          [4, 6],
          [8, 12]
        ],
        [
          [4, 6],
          [4, 6]
        ]
      ]
    >

## dot/6

Computes the generalized dot product between two tensors, given
the contracting and batch axes.

The dot product is computed by multiplying the values from `t1`
given by `contract_axes1` against the values from `t2` given by
`contract_axes2`, considering batch axes of `batch_axes1` and
`batch_axes2`. For instance, the first axis in `contract_axes1`
will be matched against the first axis in `contract_axes2` and
so on. The axes given by `contract_axes1` and `contract_axes2`
are effectively removed from the final tensor, which is why they
are often called the contraction axes.

If no contracting axes are given, the final product works like
`Nx.outer/2`.

Specifying batch axes will compute a vectorized dot product
along the given batch dimensions. The length of `batch_axes1`
and `batch_axes2` must match. Additionally, `batch_axes1` and
`batch_axes2` must be a list of successive dimension numbers,
where each batch axis matches the dimension of the corresponding
batch axis in the other input.

The contracting axes must be dot-product compatible and the
batch dimensions must always have the same number of elements.

## Examples

### Contracting along axes

    iex> t1 = Nx.tensor([[1, 2], [3, 4]], names: [:x, :y])
    iex> t2 = Nx.tensor([[10, 20], [30, 40]], names: [:height, :width])
    iex> Nx.dot(t1, [0], [], t2, [0], [])
    #Nx.Tensor<
      s32[y: 2][width: 2]
      [
        [100, 140],
        [140, 200]
      ]
    >
    iex> Nx.dot(t1, [0], [], t2, [1], [])
    #Nx.Tensor<
      s32[y: 2][height: 2]
      [
        [70, 150],
        [100, 220]
      ]
    >
    iex> Nx.dot(t1, [1], [], t2, [0], [])
    #Nx.Tensor<
      s32[x: 2][width: 2]
      [
        [70, 100],
        [150, 220]
      ]
    >
    iex> Nx.dot(t1, [1], [], t2, [1], [])
    #Nx.Tensor<
      s32[x: 2][height: 2]
      [
        [50, 110],
        [110, 250]
      ]
    >
    iex> Nx.dot(t1, [0, 1], [], t2, [0, 1], [])
    #Nx.Tensor<
      s32
      300
    >

If no axes are given, it works like `outer/2`:

    iex> t1 = Nx.tensor([[1, 2], [3, 4]])
    iex> t2 = Nx.tensor([[10, 20], [30, 40]])
    iex> Nx.dot(t1, [], [], t2, [], [])
    #Nx.Tensor<
      s32[2][2][2][2]
      [
        [
          [
            [10, 20],
            [30, 40]
          ],
          [
            [20, 40],
            [60, 80]
          ]
        ],
        [
          [
            [30, 60],
            [90, 120]
          ],
          [
            [40, 80],
            [120, 160]
          ]
        ]
      ]
    >

### Dot product between two batched tensors

    iex> u = Nx.tensor([[[1]], [[2]]])
    iex> v = Nx.tensor([[[3]], [[4]]])
    iex> Nx.dot(u, [2], [0], v, [2], [0])
    #Nx.Tensor<
      s32[2][1][1]
      [
        [
          [3]
        ],
        [
          [8]
        ]
      ]
    >

    iex> u = Nx.tensor([[[1, 1]], [[2, 2]]])
    iex> v = Nx.tensor([[[3], [3]], [[4], [4]]])
    iex> Nx.dot(u, [2], [0], v, [1], [0])
    #Nx.Tensor<
      s32[2][1][1]
      [
        [
          [6]
        ],
        [
          [16]
        ]
      ]
    >

## Vectorized tensors

If you already have vectorized axes, they will be automatically
added to the batched axes of `dot/6`. Input axes must refer to
the tensor shape, and offsets due to vectorized axes are
handled internally.

Rewriting the previous example with vectorization:

    iex> u = Nx.tensor([[[1, 1]], [[2, 2]]]) |> Nx.vectorize(:x)
    iex> v = Nx.tensor([[[3], [3]], [[4], [4]]]) |> Nx.vectorize(:x)
    iex> Nx.dot(u, [1], [], v, [0], []) # note that axes refer to the inner shapes
    #Nx.Tensor<
      vectorized[x: 2]
      s32[1][1]
      [
        [
          [6]
        ],
        [
          [16]
        ]
      ]
    >

  Because the batch axes are now empty, we can use `dot/4` to be more concise.

    Nx.dot(u, [1], v, [0])

  However, we can go even further. Since we are contracting the last axis of
  `u` with the first axis of `v`, we can rely on `dot/2` to achieve the same
  result.

      Nx.dot(u, v)

## Error cases

    iex> u = Nx.tensor([[[1, 1]], [[2, 2]]])
    iex> v = Nx.tensor([[[3], [3]], [[4], [4]]])
    iex> Nx.dot(u, [2], [0], v, [1], [])
    ** (ArgumentError) right tensor must be batched if left tensor is batched

    iex> u = Nx.tensor([[[1, 1]], [[2, 2]]])
    iex> v = Nx.tensor([[[3], [3]], [[4], [4]]])
    iex> Nx.dot(u, [2], [], v, [1], [0])
    ** (ArgumentError) left tensor must be batched if right tensor is batched

    iex> u = Nx.tensor([[[1, 1]], [[2, 2]]])
    iex> v = Nx.tensor([[[3], [3]], [[4], [4]]])
    iex> Nx.dot(u, [2], [1], v, [1], [0])
    ** (ArgumentError) invalid dot batch axis for the left tensor, batch axes must be successive dimensions starting from 0, got [1]

    iex> u = Nx.tensor([[[1, 1]], [[2, 2]]])
    iex> v = Nx.tensor([[[3], [3]], [[4], [4]]])
    iex> Nx.dot(u, [2], [0], v, [1], [1])
    ** (ArgumentError) invalid dot batch axis for the right tensor, batch axes must be successive dimensions starting from 0, got [1]

    iex> u = Nx.tensor([[[1, 1]], [[2, 2]]])
    iex> v = Nx.tensor([[[3], [3]], [[4], [4]]])
    iex> Nx.dot(u, [0], [0], v, [1], [0])
    ** (ArgumentError) dot batch axes for left tensor ([0]) cannot be in contract axes ([0])

    iex> u = Nx.tensor([[[1, 1]], [[2, 2]]])
    iex> v = Nx.tensor([[[3], [3]], [[4], [4]]])
    iex> Nx.dot(u, [2], [0], v, [0], [0])
    ** (ArgumentError) dot batch axes for right tensor ([0]) cannot be in contract axes ([0])

## outer/2

Computes the outer product of two tensors.

The output is always a two-dimensional tensor.

## Examples

    iex> Nx.outer(Nx.tensor([1, 2, 3], names: [:x]), 100)
    #Nx.Tensor<
      s32[x: 3][1]
      [
        [100],
        [200],
        [300]
      ]
    >

    iex> Nx.outer(Nx.tensor([1, 2, 3], names: [:x]), Nx.tensor([10, 20], names: [:y]))
    #Nx.Tensor<
      s32[x: 3][y: 2]
      [
        [10, 20],
        [20, 40],
        [30, 60]
      ]
    >

    iex> Nx.outer(Nx.tensor([[1, 2], [3, 4]], names: [:x, :y]), Nx.tensor([10, 20, 30], names: [:z]))
    #Nx.Tensor<
      s32[x: 4][z: 3]
      [
        [10, 20, 30],
        [20, 40, 60],
        [30, 60, 90],
        [40, 80, 120]
      ]
    >

## Vectorized tensors

Because `outer/2` is built on top of other

    iex> x = Nx.tensor([[1, 2, 3], [0, -1, -2]], names: [nil, :a]) |> Nx.vectorize(:x)
    iex> y = Nx.tensor([[10, 20], [-10, -20]], names: [nil, :b]) |> Nx.vectorize(:y)
    iex> Nx.outer(x, y)
    #Nx.Tensor<
      vectorized[x: 2][y: 2]
      s32[a: 3][b: 2]
      [
        [
          [
            [10, 20],
            [20, 40],
            [30, 60]
          ],
          [
            [-10, -20],
            [-20, -40],
            [-30, -60]
          ]
        ],
        [
          [
            [0, 0],
            [-10, -20],
            [-20, -40]
          ],
          [
            [0, 0],
            [10, 20],
            [20, 40]
          ]
        ]
      ]
    >

## transpose/2

Transposes a tensor to the given `axes`.

If no axes are given, the default behavior is to
reverse the order of the original tensor's axes.

The axes is a list of integers or dimension names
containing how the new dimensions must be ordered.
The highest dimension is zero.

## Examples

    iex> Nx.transpose(Nx.tensor(1))
    #Nx.Tensor<
      s32
      1
    >

    iex> Nx.transpose(Nx.iota({2, 3, 4}, names: [:x, :y, :z]))
    #Nx.Tensor<
      s32[z: 4][y: 3][x: 2]
      [
        [
          [0, 12],
          [4, 16],
          [8, 20]
        ],
        [
          [1, 13],
          [5, 17],
          [9, 21]
        ],
        [
          [2, 14],
          [6, 18],
          [10, 22]
        ],
        [
          [3, 15],
          [7, 19],
          [11, 23]
        ]
      ]
    >

    iex> Nx.transpose(Nx.tensor(1), axes: [])
    #Nx.Tensor<
      s32
      1
    >

    iex> Nx.transpose(Nx.iota({2, 3, 4}, names: [:batch, :x, :y]), axes: [2, 1, :batch])
    #Nx.Tensor<
      s32[y: 4][x: 3][batch: 2]
      [
        [
          [0, 12],
          [4, 16],
          [8, 20]
        ],
        [
          [1, 13],
          [5, 17],
          [9, 21]
        ],
        [
          [2, 14],
          [6, 18],
          [10, 22]
        ],
        [
          [3, 15],
          [7, 19],
          [11, 23]
        ]
      ]
    >

### Vectorized tensors

For vectorized tensors, transpose will manipulate the inner shape only,
keeping the order of vectorized axes the same.

    iex> v = Nx.vectorize(Nx.iota({1, 2, 3}), :x)
    #Nx.Tensor<
      vectorized[x: 1]
      s32[2][3]
      [
        [
          [0, 1, 2],
          [3, 4, 5]
        ]
      ]
    >
    iex> Nx.transpose(v)
    #Nx.Tensor<
      vectorized[x: 1]
      s32[3][2]
      [
        [
          [0, 3],
          [1, 4],
          [2, 5]
        ]
      ]
    >
    iex> Nx.transpose(v, axes: [1, 0])
    #Nx.Tensor<
      vectorized[x: 1]
      s32[3][2]
      [
        [
          [0, 3],
          [1, 4],
          [2, 5]
        ]
      ]
    >

### Errors

    iex> Nx.transpose(Nx.iota({2, 2}, names: [:batch, :x]), axes: [:batch])
    ** (ArgumentError) expected length of permutation (1) to match rank of shape (2)

    iex> Nx.transpose(Nx.iota({2, 2}), axes: [1, 2])
    ** (ArgumentError) given axis (2) invalid for shape with rank 2

## reverse/2

Reverses the tensor in the given dimensions.

If no axes are provided, reverses every axis.

You can pass either names or numbers for the reverse
dimensions. Dimensions must be unique, but they do not
have to be successive.

## Examples

    iex> Nx.reverse(Nx.tensor([1, 2, 3]))
    #Nx.Tensor<
      s32[3]
      [3, 2, 1]
    >

    iex> Nx.reverse(Nx.tensor([[1, 2, 3], [4, 5, 6]]))
    #Nx.Tensor<
      s32[2][3]
      [
        [6, 5, 4],
        [3, 2, 1]
      ]
    >

    iex> Nx.reverse(Nx.tensor([1, 2, 3], names: [:x]), axes: [:x])
    #Nx.Tensor<
      s32[x: 3]
      [3, 2, 1]
    >

    iex> Nx.reverse(Nx.tensor([[1, 2, 3], [4, 5, 6]], names: [:x, :y]), axes: [:x])
    #Nx.Tensor<
      s32[x: 2][y: 3]
      [
        [4, 5, 6],
        [1, 2, 3]
      ]
    >

    iex> Nx.reverse(Nx.tensor([[1, 2, 3], [4, 5, 6]], names: [:x, :y]), axes: [:y])
    #Nx.Tensor<
      s32[x: 2][y: 3]
      [
        [3, 2, 1],
        [6, 5, 4]
      ]
    >

    iex> Nx.reverse(Nx.iota({2, 2, 2}, type: :f32, names: [:x, :y, :z]), axes: [:x, :z])
    #Nx.Tensor<
      f32[x: 2][y: 2][z: 2]
      [
        [
          [5.0, 4.0],
          [7.0, 6.0]
        ],
        [
          [1.0, 0.0],
          [3.0, 2.0]
        ]
      ]
    >

### Vectorized tensors

For vectorized tensors, the `:axes` refer to the non-vectorized part.
Vectorized axes will always remain unchanged.

    iex> v = Nx.vectorize(Nx.iota({1, 2, 3}), :x)
    #Nx.Tensor<
      vectorized[x: 1]
      s32[2][3]
      [
        [
          [0, 1, 2],
          [3, 4, 5]
        ]
      ]
    >
    iex> Nx.reverse(v)
    #Nx.Tensor<
      vectorized[x: 1]
      s32[2][3]
      [
        [
          [5, 4, 3],
          [2, 1, 0]
        ]
      ]
    >
    iex> Nx.reverse(v, axes: [1])
    #Nx.Tensor<
      vectorized[x: 1]
      s32[2][3]
      [
        [
          [2, 1, 0],
          [5, 4, 3]
        ]
      ]
    >

## conv/3

Computes an n-D convolution (where `n >= 3`) as used in neural networks.

This function can be thought of as sliding an n-D
kernel across the input, producing a new tensor that
has the same number of elements as the number of valid
windows in the input tensor. Each element is the result
of summing the element-wise products in the window across
each input channel.

> #### Kernel Reflection {: .info}
>
> See the note at the end of this section for more details
> on the convention for kernel reflection and conjugation.

The ranks of both `input` and `kernel` must match. By
default, both `input` and `kernel` are expected to have shapes
of the following form:

  * `input` - `{batch_size, input_channels, input_d0, ..., input_dn}`
  * `kernel` - `{output_channels, input_channels, kernel_d0, ..., kernel_dn}`

Where `input_d0...input_dn` and `kernel_d0...kernel_dn` represent
an arbitrary number of spatial dimensions. You can alter this configuration
using one of the `*_permutation` configuration options. Permutations
are input, kernel, and output specifications for the layout of the
convolution. For example, if your input tensor is configured with
"channels last", you can specify the input permutation with:

    Nx.conv(img, kernel, input_permutation: [0, 3, 1, 2])

Permutations expect configurations that specify the location of
dimensions in the following orders:

  * `input_permutation` - `[batch_dim, input_channel_dim, ...spatial_dims...]`
  * `kernel_permutation` - `[output_channel_dim, input_channel_dim, ...spatial_dims...]`
  * `output_permutation` - `[batch_dim, output_channel_dim, ...spatial_dims...]`

Using named tensors, it's a bit easier to see how permutations
help you configure the convolution. Given input tensor with names
`[:batch, :height, :width, :channels]` (channels last) and kernel
tensor with names `[:input, :output, :height, :width]`, you can
configure the convolution with the following permutations:

    Nx.conv(img, kernel,
      input_permutation: [:batch, :channels, :height, :width],
      kernel_permutation: [:output, :input, :height, :width],
      output_permutation: [:batch, :channels, :height, :width]
    )

Notice that `output_permutation` is normalized with respect to
the input permutation names. We cannot guarantee that every
permutation is supported in every backend or compiler.

To configure how the window slides along the input tensor, you
can specify `:strides`. `:strides` must be a positive integer
or tuple of positive integers for each spatial dimension
in the input and kernel. For each spatial dimension, the
window will slide by the configuration specified in `:strides`.
As an example, for a 2-D convolution with `strides: [2, 1]`,
the window will slide 2 positions along the first spatial
dimension until it reaches the end of the dimension and then
1 position along the second spatial dimension.

You may specify a padding configuration using `:padding`,
which will zero-pad the input tensor. Acceptable padding
configurations are:

  * `:valid` - no padding
  * `:same` - pad input spatial dimensions such that they
  will remain unchanged in the output tensor
  * `[{d0_hi, d0_lo}, ..., {dn_hi, dn_lo}]` - a general padding
  configuration of edge high and edge low padding values. You
  may only specify padding for the edges of spatial dimensions
  of the input tensor. Padding values may be negative.

You can dilate convolutions by setting `:input_dilation` or
`:kernel_dilation`. Both `:input_dilation` and `:kernel_dilation`
must either be positive integers or tuples of positive integers
for each spatial dimension in the input and kernel tensors. Dilations
can be thought of as applying `dilation - 1` interior padding to the
input or kernel tensor.

You can split both the input and kernel tensor into feature groups
using `:feature_group_size`. This will split both the input and kernel
tensor channels and compute a grouped convolution. The size of the
kernel input feature channels times the size of the feature group must
match the size of the input tensor feature channels. Additionally,
the size of the kernel output feature channels must be evenly divisible
by the group size.

You can also split the input tensor along the batch dimension by
specifying `:batch_group_size`. This will compute a grouped convolution
in the same way as with `:feature_group_size`, however, the input
tensor will be split into groups along the batch dimension.

> #### Convolution vs Correlation {: .tip}
>
> `conv/3` does not perform reversion of the kernel.
> This means that if you come from a Signal Processing background,
> you might treat it as a cross-correlation operation instead of a convolution.
>
> This function is not exactly a cross-correlation function, as it does not
> perform conjugation of the kernel, as is done in [scipy.signal.correlate](https://docs.scipy.org/doc/scipy/reference/generated/scipy.signal.correlate.html).
> This can be remedied via `Nx.conjugate/1`, as seen below:
>
> ```elixir
> kernel =
>   if Nx.Type.complex?(Nx.type(kernel)) do
>     Nx.conjugate(kernel)
>   else
>     kernel
>   end
>
> Nx.conv(tensor, kernel)
> ```
>
> If you need the proper Signal Processing convolution, such as the one in
> [scipy.signal.convolve](https://docs.scipy.org/doc/scipy/reference/generated/scipy.signal.convolve.html),
> you can use `reverse/2`, like in the example:
>
> ```elixir
> reversal_axes =
>   case Nx.rank(kernel) do
>     0 -> []
>     1 -> [1]
>     2 -> [0, 1]
>     _ -> Enum.drop(Nx.axes(kernel), 2)
>   end
>
> kernel = Nx.reverse(kernel, axes: reversal_axes)
>
> Nx.conv(tensor, kernel)
> ```

## Examples

    iex> left = Nx.iota({1, 1, 3, 3})
    iex> right = Nx.iota({4, 1, 1, 1})
    iex> Nx.conv(left, right, strides: [1, 1])
    #Nx.Tensor<
      f32[1][4][3][3]
      [
        [
          [
            [0.0, 0.0, 0.0],
            [0.0, 0.0, 0.0],
            [0.0, 0.0, 0.0]
          ],
          [
            [0.0, 1.0, 2.0],
            [3.0, 4.0, 5.0],
            [6.0, 7.0, 8.0]
          ],
          [
            [0.0, 2.0, 4.0],
            [6.0, 8.0, 10.0],
            [12.0, 14.0, 16.0]
          ],
          [
            [0.0, 3.0, 6.0],
            [9.0, 12.0, 15.0],
            [18.0, 21.0, 24.0]
          ]
        ]
      ]
    >

    iex> left = Nx.iota({1, 1, 3, 3})
    iex> right = Nx.iota({4, 1, 2, 1})
    iex> Nx.conv(left, right, strides: 2, padding: :same, kernel_dilation: [2, 1])
    #Nx.Tensor<
      f32[1][4][2][2]
      [
        [
          [
            [3.0, 5.0],
            [0.0, 0.0]
          ],
          [
            [9.0, 15.0],
            [6.0, 10.0]
          ],
          [
            [15.0, 25.0],
            [12.0, 20.0]
          ],
          [
            [21.0, 35.0],
            [18.0, 30.0]
          ]
        ]
      ]
    >

Complex tensors are also supported:

    iex> left = Nx.tensor([[[Complex.new(1, 1), 2, Complex.new(3, -3)]]])
    iex> right = Nx.tensor([[[1, Complex.new(0, 2), Complex.new(0, 3)]]])
    iex> Nx.conv(left, right, padding: [{2, 2}])
    #Nx.Tensor<
      c64[1][1][5]
      [
        [
          [-3.0+3.0i, -2.0+8.0i, 10.0+14.0i, 8.0+6.0i, 3.0-3.0i]
        ]
      ]
    >

## clip/3

Clips the values of the tensor on the closed
interval `[min, max]`.

You can pass a tensor to `min` or `max` as long
as the tensor has a scalar shape.

## Examples

    iex> t = Nx.tensor([[1, 2, 3], [4, 5, 6]], names: [:x, :y])
    iex> Nx.clip(t, 2, 4)
    #Nx.Tensor<
      s32[x: 2][y: 3]
      [
        [2, 2, 3],
        [4, 4, 4]
      ]
    >

    iex> t = Nx.tensor([[1, 2, 3], [4, 5, 6]], names: [:x, :y])
    iex> Nx.clip(t, 2.0, 3)
    #Nx.Tensor<
      f32[x: 2][y: 3]
      [
        [2.0, 2.0, 3.0],
        [3.0, 3.0, 3.0]
      ]
    >

    iex> t = Nx.tensor([[1, 2, 3], [4, 5, 6]], names: [:x, :y])
    iex> Nx.clip(t, Nx.tensor(2.0), Nx.max(1.0, 3.0))
    #Nx.Tensor<
      f32[x: 2][y: 3]
      [
        [2.0, 2.0, 3.0],
        [3.0, 3.0, 3.0]
      ]
    >

    iex> t = Nx.tensor([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]], names: [:x, :y])
    iex> Nx.clip(t, 2, 6.0)
    #Nx.Tensor<
      f32[x: 2][y: 3]
      [
        [2.0, 2.0, 3.0],
        [4.0, 5.0, 6.0]
      ]
    >

    iex> t = Nx.tensor([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]], type: :f32, names: [:x, :y])
    iex> Nx.clip(t, 1, 4)
    #Nx.Tensor<
      f32[x: 2][y: 3]
      [
        [1.0, 2.0, 3.0],
        [4.0, 4.0, 4.0]
      ]
    >

## Vectorized tensors

Only the main input tensor is allowed to be vectorized. `min` and `max` threshold tensors
must be unvectorized scalar tensors.

    iex> t = Nx.tensor([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]], type: :f32, names: [nil, :y]) |> Nx.vectorize(:x)
    iex> Nx.clip(t, 1, 4)
    #Nx.Tensor<
      vectorized[x: 2]
      f32[y: 3]
      [
        [1.0, 2.0, 3.0],
        [4.0, 4.0, 4.0]
      ]
    >

## slice/4

Slices a tensor from `start_indices` with `lengths`.

You can optionally provide a `stride` to specify the amount
of stride in each dimension.

Both start indices and lengths must match the rank of the
input tensor shape. All start indexes must be greater than
or equal to zero. All lengths must be strictly greater than
zero. If `start_index + length` exceeds the tensor dimension,
the `start_index` will be clipped in order to guarantee the
`length` is the requested one. See the "Clipping" section below.

It is possible for `start_indices` to be a list of tensors.
However, `lengths` must always be a list of integers. If you
want to specify a tensor as the list of indices, see `take/3`.

If the `:strides` is given, it must be strictly greater than zero.
The resulting tensor will have the shape of `length` unless
`:strides` are given.

It is not possible to slice in reverse. See `gather/2`,
`slice_along_axis/4`, `take/3`, and `take_along_axis/3` for other ways
to retrieve values from a tensor.

## Examples

    iex> Nx.slice(Nx.tensor([1, 2, 3, 4, 5, 6]), [0], [3])
    #Nx.Tensor<
      s32[3]
      [1, 2, 3]
    >

    iex> Nx.slice(Nx.tensor([1, 2, 3, 4, 5, 6]), [0], [6], strides: [2])
    #Nx.Tensor<
      s32[3]
      [1, 3, 5]
    >

    iex> Nx.slice(Nx.tensor([[1, 2], [3, 4], [5, 6]]), [0, 0], [3, 2], strides: [2, 1])
    #Nx.Tensor<
      s32[2][2]
      [
        [1, 2],
        [5, 6]
      ]
    >

Strides can also be a number that applies to all dimensions:

    iex> t = Nx.tensor([[1, 2], [3, 4], [5, 6]])
    iex> Nx.slice(t, [0, 0], [3, 2], strides: 2)
    #Nx.Tensor<
      s32[2][1]
      [
        [1],
        [5]
      ]
    >

A more complex example:

    iex> t = Nx.iota({2, 15, 30})
    iex> Nx.slice(t, [0, 4, 11], [2, 3, 9], strides: [2, 1, 3])
    #Nx.Tensor<
      s32[1][3][3]
      [
        [
          [131, 134, 137],
          [161, 164, 167],
          [191, 194, 197]
        ]
      ]
    >

## Tensors as `start_indices`

The `start_indices` list can be made of scalar tensors:

    iex> Nx.slice(Nx.tensor([[1, 2, 3], [4, 5, 6]]), [Nx.tensor(1), Nx.tensor(2)], [1, 1])
    #Nx.Tensor<
      s32[1][1]
      [
        [6]
      ]
    >

    iex> t = Nx.tensor([
    ...>   [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    ...>   [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    ...>   [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
    ...>   [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
    ...>   [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
    ...>   [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]
    ...> ])
    iex> Nx.slice(t, [Nx.tensor(0), Nx.tensor(0)], [6, 7], strides: [5, 3])
    #Nx.Tensor<
      f32[2][3]
      [
        [0.0, 0.0, 0.0],
        [1.0, 1.0, 1.0]
      ]
    >

## Clipping

`slice/3` will always guarantee the return tensor has the
given `lengths`. See the following example:

    iex> Nx.slice(Nx.iota({3, 3}), [2, 2], [1, 1])
    #Nx.Tensor<
      s32[1][1]
      [
        [8]
      ]
    >

In the example above, `start_index + length <= dimension`,
so there is no clipping. However, if the `start_index + length`
is to exceed the dimension, the index will be clipped in order
to guarantee the given lengths:

    iex> Nx.slice(Nx.iota({3, 3}), [2, 2], [2, 2])
    #Nx.Tensor<
      s32[2][2]
      [
        [4, 5],
        [7, 8]
      ]
    >

This also applies when the start index is given by tensors:

    iex> Nx.slice(Nx.iota({3, 3}), [Nx.tensor(2), Nx.tensor(2)], [2, 2])
    #Nx.Tensor<
      s32[2][2]
      [
        [4, 5],
        [7, 8]
      ]
    >

## Vectorized tensors

Both the tensor to be sliced and the indices can be vectorized.

    iex> Nx.slice(Nx.iota({3, 3}, vectorized_axes: [x: 2]), [0, Nx.tensor(1)], [2, 2])
    #Nx.Tensor<
      vectorized[x: 2]
      s32[2][2]
      [
        [
          [1, 2],
          [4, 5]
        ],
        [
          [1, 2],
          [4, 5]
        ]
      ]
    >

    iex> idx = Nx.tensor([0, 1, 10]) |> Nx.vectorize(:i)
    iex> Nx.slice(Nx.iota({3, 3}), [0, idx], [2, 2])
    #Nx.Tensor<
      vectorized[i: 3]
      s32[2][2]
      [
        [
          [0, 1],
          [3, 4]
        ],
        [
          [1, 2],
          [4, 5]
        ],
        [
          [1, 2],
          [4, 5]
        ]
      ]
    >

## Error cases

    iex> Nx.slice(Nx.tensor([[1, 2, 3], [4, 5, 6]]), [Nx.tensor([1, 2]), Nx.tensor(1)], [1, 1])
    ** (ArgumentError) index must be scalar, got shape {2} for axis 0

    iex> Nx.slice(Nx.tensor([[1, 2, 3], [4, 5, 6]]), [Nx.tensor(1.0), Nx.tensor(0)], [1, 1])
    ** (ArgumentError) index must be integer type, got {:f, 32} for axis 0

## Scalars

Slicing a scalar tensor returns the scalar itself:

    iex> Nx.slice(Nx.tensor(42), [], [])
    #Nx.Tensor<
      s32
      42
    >

## slice_along_axis/4

Slices a tensor along the given axis.

You can optionally provide a `stride` to specify the amount
of stride in along the given dimension.

Start index must be greater than or equal to zero. It can be an
integer or a scalar tensor. Length must be strictly greater than
zero. `start_index + length` must not exceed the respective tensor
dimension.

The axis will be normalized with the dimensions and names of the
given tensor.

If the `:strides` is given, it must be strictly greater than zero.

It is not possible to slice in reverse. See `gather/2`, `slice/3`,
`take/3`, and `take_along_axis/3` for other ways to retrieve values
from a tensor.

## Options

  * `:axis` - The axis along which to take the values from. Defaults to `0`.
  * `:strides` - The stride to slice the axis along of. Defaults to `1`.

## Examples

    iex> Nx.slice_along_axis(Nx.iota({5, 2}), 1, 2, axis: 0)
    #Nx.Tensor<
      s32[2][2]
      [
        [2, 3],
        [4, 5]
      ]
    >

    iex> Nx.slice_along_axis(Nx.iota({2, 5}), 1, 2, axis: 1)
    #Nx.Tensor<
      s32[2][2]
      [
        [1, 2],
        [6, 7]
      ]
    >

    iex> Nx.slice_along_axis(Nx.iota({2, 5}, names: [:x, :y]), 0, 1, axis: :x)
    #Nx.Tensor<
      s32[x: 1][y: 5]
      [
        [0, 1, 2, 3, 4]
      ]
    >

    iex> Nx.slice_along_axis(Nx.iota({2, 5}, names: [:x, :y]), Nx.tensor(0), 1, axis: :x)
    #Nx.Tensor<
      s32[x: 1][y: 5]
      [
        [0, 1, 2, 3, 4]
      ]
    >

    iex> Nx.slice_along_axis(Nx.iota({2, 5}), 0, 3, axis: -1, strides: 2)
    #Nx.Tensor<
      s32[2][2]
      [
        [0, 2],
        [5, 7]
      ]
    >

## Vectorized tensors

Slices are taken over each vectorized entry.
The `start_index` cannot be vectorized.

    iex> t = Nx.iota({2, 5}, vectorized_axes: [x: 2])
    iex> Nx.slice_along_axis(t, 0, 3, axis: 1, strides: 2)
    #Nx.Tensor<
      vectorized[x: 2]
      s32[2][2]
      [
        [
          [0, 2],
          [5, 7]
        ],
        [
          [0, 2],
          [5, 7]
        ]
      ]
    >

## put_slice/3

Puts the given `slice` into the given `tensor` at the given
`start_indices`.

The given slice must be of the same rank as tensor. Each axis
must be less than or equal to the size to the equivalent axis
in the tensor.

The number of elements in `start_indices` should match the
rank of the tensor.

See also: `indexed_add/3`, `indexed_put/3`.

## Examples

    iex> t = Nx.tensor([0, 1, 2, 3, 4])
    iex> Nx.put_slice(t, [2], Nx.tensor([5, 6]))
    #Nx.Tensor<
      s32[5]
      [0, 1, 5, 6, 4]
    >

    iex> t = Nx.tensor([[1, 2, 3], [4, 5, 6]])
    iex> Nx.put_slice(t, [0, 1], Nx.tensor([[7, 8], [9, 10]]))
    #Nx.Tensor<
      s32[2][3]
      [
        [1, 7, 8],
        [4, 9, 10]
      ]
    >

Similar to `slice/3`, dynamic start indexes are also supported:

    iex> t = Nx.tensor([[1, 2, 3], [4, 5, 6]])
    iex> Nx.put_slice(t, [Nx.tensor(0), Nx.tensor(1)], Nx.tensor([[10.0, 11.0]]))
    #Nx.Tensor<
      f32[2][3]
      [
        [1.0, 10.0, 11.0],
        [4.0, 5.0, 6.0]
      ]
    >

Also similar to `slice/3`, if `start_index + slice_dimension > dimension`,
the start index will be clipped in order to put the whole slice:

    iex> t = Nx.tensor([[1, 2, 3], [4, 5, 6]])
    iex> Nx.put_slice(t, [1, 1], Nx.tensor([[7, 8], [9, 10]]))
    #Nx.Tensor<
      s32[2][3]
      [
        [1, 7, 8],
        [4, 9, 10]
      ]
    >

## Vectorized tensors

The both tensor to be sliced and the slices can be vectorized,
but indices must be non-vectorized.

    iex> t = Nx.tensor([[1, 2, 3, 4], [5, 6, 7, 8]]) |> Nx.vectorize(:x)
    iex> slice = Nx.tensor([[10, 20], [30, 40]]) |> Nx.vectorize(:y)
    iex> Nx.put_slice(t, [2], slice)
    #Nx.Tensor<
      vectorized[x: 2][y: 2]
      s32[4]
      [
        [
          [1, 2, 10, 20],
          [1, 2, 30, 40]
        ],
        [
          [5, 6, 10, 20],
          [5, 6, 30, 40]
        ]
      ]
    >

## take/3

Takes and concatenates slices along an axis.

Intuitively speaking, `take/3` reorders tensor slices along
the given axis based on the given indices, possibly duplicating
and removing slices.

Passing a multi-dimensional indices tensor only affects the
resulting shape. Specifically, the given axis in the input shape
gets replaced with the indices shape.

See `gather/2`, `slice/3`, `slice_along_axis/4`, and `take_along_axis/3`
for other ways to retrieve values from a tensor.

## Options

  * `:axis` - an axis to take tensor slices over. Defaults to 0.

## Examples

    iex> t = Nx.tensor([[1, 2], [3, 4]])
    iex> Nx.take(t, Nx.tensor([1, 0, 1]))
    #Nx.Tensor<
      s32[3][2]
      [
        [3, 4],
        [1, 2],
        [3, 4]
      ]
    >

    iex> t = Nx.tensor([[1, 2], [3, 4]])
    iex> Nx.take(t, Nx.tensor([1, 0, 1]), axis: 1)
    #Nx.Tensor<
      s32[2][3]
      [
        [2, 1, 2],
        [4, 3, 4]
      ]
    >


    iex> t = Nx.tensor([[1, 2], [3, 4]], names: [:x, :y])
    iex> Nx.take(t, Nx.tensor([1, 0, 1]), axis: :y)
    #Nx.Tensor<
      s32[x: 2][y: 3]
      [
        [2, 1, 2],
        [4, 3, 4]
      ]
    >

    iex> t = Nx.tensor([[[1, 2], [11, 12]], [[101, 102], [111, 112]]])
    iex> Nx.take(t, Nx.tensor([1, 0, 1]), axis: 1)
    #Nx.Tensor<
      s32[2][3][2]
      [
        [
          [11, 12],
          [1, 2],
          [11, 12]
        ],
        [
          [111, 112],
          [101, 102],
          [111, 112]
        ]
      ]
    >

Multi-dimensional indices tensor:

    iex> t = Nx.tensor([[1, 2], [11, 12]])
    iex> Nx.take(t, Nx.tensor([[0, 0], [1, 1], [0, 0]]), axis: 1)
    #Nx.Tensor<
      s32[2][3][2]
      [
        [
          [1, 1],
          [2, 2],
          [1, 1]
        ],
        [
          [11, 11],
          [12, 12],
          [11, 11]
        ]
      ]
    >

    iex> t = Nx.tensor([[[1, 2], [11, 12]], [[101, 102], [111, 112]]])
    iex> Nx.take(t, Nx.tensor([[0, 0, 0], [1, 1, 1], [0, 0, 0]]), axis: 1)
    #Nx.Tensor<
      s32[2][3][3][2]
      [
        [
          [
            [1, 2],
            [1, 2],
            [1, 2]
          ],
          [
            [11, 12],
            [11, 12],
            [11, 12]
          ],
          [
            [1, 2],
            [1, 2],
            [1, 2]
          ]
        ],
        [
          [
            [101, 102],
            [101, 102],
            [101, 102]
          ],
          [
            [111, 112],
            [111, 112],
            [111, 112]
          ],
          [
            [101, 102],
            [101, 102],
            [101, 102]
          ]
        ]
      ]
    >

## Vectorized tensors

`tensor` and `indices` have their vectorized axes broadcast together,
and then the operation takes place normally, with `:axis` and `indices`
having their values in reference to the input shape.

    iex> t = Nx.tensor([[1, 2], [11, 12]])
    iex> idx = Nx.tensor([0, 1, 0]) |> Nx.vectorize(:x)
    iex> Nx.take(t, idx)
    #Nx.Tensor<
      vectorized[x: 3]
      s32[2]
      [
        [1, 2],
        [11, 12],
        [1, 2]
      ]
    >
    iex> t = Nx.tensor([[[1, 2]], [[11, 12]]]) |> Nx.vectorize(:x)
    iex> idx = Nx.tensor([0, 1])
    iex> Nx.take(t, idx, axis: 1)
    #Nx.Tensor<
      vectorized[x: 2]
      s32[1][2]
      [
        [
          [1, 2]
        ],
        [
          [11, 12]
        ]
      ]
    >

In case both inputs are vectorized, they will be broadcasted
together before calculations are performed:

    iex> t = Nx.tensor([[1, 2], [11, 12]]) |> Nx.vectorize(:x)
    iex> idx = Nx.tensor([0, 1, 0]) |> Nx.vectorize(:y)
    iex> Nx.take(t, idx)
    #Nx.Tensor<
      vectorized[x: 2][y: 3]
      s32
      [
        [1, 2, 1],
        [11, 12, 11]
      ]
    >

    iex> t = Nx.tensor([[1, 2], [11, 12]]) |> Nx.vectorize(:x)
    iex> idx = Nx.tensor([[0, 1, 0], [0, 1, 1]]) |> Nx.vectorize(:x)
    iex> Nx.take(t, idx)
    #Nx.Tensor<
      vectorized[x: 2]
      s32[3]
      [
        [1, 2, 1],
        [11, 12, 12]
      ]
    >

## Error cases

    iex> Nx.take(Nx.tensor([[1, 2], [3, 4]]), Nx.tensor([1, 0, 1], type: :f32))
    ** (ArgumentError) indices must be an integer tensor, got {:f, 32}

## take_along_axis/3

Takes the values from a tensor given an `indices` tensor, along the specified axis.

The `indices` shape must be the same as the `tensor`'s shape, with the exception for
the `axis` dimension, which can have arbitrary size. The returned tensor will have the
same shape as the `indices` tensor.

See `gather/2`, `slice/3`, `slice_along_axis/4`, and `take/3` for other ways to retrieve
values from a tensor.

## Options

  * `:axis` - The axis along which to take the values from. Defaults to `0`.

## Examples

    iex> t = Nx.tensor([[1, 2, 3], [4, 5, 6]])
    iex> Nx.take_along_axis(t, Nx.tensor([[0, 0, 2, 2, 1, 1], [2, 2, 1, 1, 0, 0]]), axis: 1)
    #Nx.Tensor<
      s32[2][6]
      [
        [1, 1, 3, 3, 2, 2],
        [6, 6, 5, 5, 4, 4]
      ]
    >

    iex> t = Nx.tensor([[1, 2, 3], [4, 5, 6]])
    iex> Nx.take_along_axis(t, Nx.tensor([[0, 1, 1], [1, 0, 0], [0, 1, 0]]), axis: 0)
    #Nx.Tensor<
      s32[3][3]
      [
        [1, 5, 6],
        [4, 2, 3],
        [1, 5, 3]
      ]
    >

The indices returned from `Nx.argsort/2` can be used with `Nx.take_along_axis/3` to
produce the sorted tensor (or to sort more tensors according to the same criteria).

    iex> tensor = Nx.tensor([[[1, 2], [3, 4], [5, 6]]])
    #Nx.Tensor<
      s32[1][3][2]
      [
        [
          [1, 2],
          [3, 4],
          [5, 6]
        ]
      ]
    >
    iex> idx1 = Nx.argsort(tensor, axis: 1, direction: :desc)
    #Nx.Tensor<
      s32[1][3][2]
      [
        [
          [2, 2],
          [1, 1],
          [0, 0]
        ]
      ]
    >
    iex> Nx.take_along_axis(tensor, idx1, axis: 1)
    #Nx.Tensor<
      s32[1][3][2]
      [
        [
          [5, 6],
          [3, 4],
          [1, 2]
        ]
      ]
    >
    iex> idx2 = Nx.argsort(tensor, axis: 2, direction: :desc)
    #Nx.Tensor<
      s32[1][3][2]
      [
        [
          [1, 0],
          [1, 0],
          [1, 0]
        ]
      ]
    >
    iex> Nx.take_along_axis(tensor, idx2, axis: 2)
    #Nx.Tensor<
      s32[1][3][2]
      [
        [
          [2, 1],
          [4, 3],
          [6, 5]
        ]
      ]
    >

## Vectorized tensors

`tensor` and `indices` have their vectorized axes broadcast together,
and then the operation takes place normally, with `:axis` and `indices`
having their values in reference to the input shape.

    iex> t = Nx.tensor([[[1, 2, 3]], [[4, 5, 6]]]) |> Nx.vectorize(:x)
    iex> idx = Nx.tensor([[[0, 0, 2, 1]], [[2, 1, 0, 0]]]) |> Nx.vectorize(:x)
    iex> Nx.take_along_axis(t, idx, axis: 1)
    #Nx.Tensor<
      vectorized[x: 2]
      s32[1][4]
      [
        [
          [1, 1, 3, 2]
        ],
        [
          [6, 5, 4, 4]
        ]
      ]
    >

In the example below, we have broadcasting throughout the vectorized axes

    iex> t = Nx.tensor([[1, 2, 3], [4, 5, 6]]) |> Nx.vectorize(:x)
    iex> idx = Nx.tensor([[0, 0, 2, 1], [2, 1, 0, 0]]) |> Nx.vectorize(:y)
    iex> Nx.take_along_axis(t, idx, axis: 0)
    #Nx.Tensor<
      vectorized[x: 2][y: 2]
      s32[4]
      [
        [
          [1, 1, 3, 2],
          [3, 2, 1, 1]
        ],
        [
          [4, 4, 6, 5],
          [6, 5, 4, 4]
        ]
      ]
    >

## Error cases

    iex> tensor = Nx.iota({3, 3})
    iex> idx = Nx.tensor([[2.0], [1.0], [2.0]], type: :f32)
    iex> Nx.take_along_axis(tensor, idx, axis: 1)
    ** (ArgumentError) indices must be an integer tensor, got {:f, 32}

## gather/3

Builds a new tensor by taking individual values from the original
tensor at the given indices.

Indices must be a tensor where the last dimension is usually of the
same size as the `tensor` rank. Each entry in `indices` will be
part of the results. If the last dimension of indices is less than
the `tensor` rank, then a multidimensional tensor is gathered and
spliced into the result.

## Options

  * `:axes` - controls to which dimensions of `tensor`
    each element in the last dimension of `indexes` applies to.
    It defaults so the first element in indexes apply to the first
    axis, the second to the second, and so on. It must be a sorted
    list of axes and be of the same size as the last dimension of
    the indexes tensor.

## Examples

### Gathering scalars

    iex> t = Nx.tensor([[1, 2], [3, 4]])
    iex> Nx.gather(t, Nx.tensor([[1, 1], [0, 1], [1, 0]]))
    #Nx.Tensor<
      s32[3]
      [4, 2, 3]
    >

    iex> t = Nx.tensor([[1, 2], [3, 4]])
    iex> Nx.gather(t, Nx.tensor([[[1, 1], [0, 0]], [[1, 0], [0, 1]]]))
    #Nx.Tensor<
      s32[2][2]
      [
        [4, 1],
        [3, 2]
      ]
    >

    iex> t = Nx.tensor([[[1, 2], [11, 12]], [[101, 102], [111, 112]]])
    iex> Nx.gather(t, Nx.tensor([[0, 0, 0], [0, 1, 1], [1, 1, 1]]))
    #Nx.Tensor<
      s32[3]
      [1, 12, 112]
    >

### Gathering subsets

    iex> t = Nx.tensor([[1, 2, 3], [3, 4, 5]])
    iex> Nx.gather(t, Nx.tensor([[1], [0]]))
    #Nx.Tensor<
      s32[2][3]
      [
        [3, 4, 5],
        [1, 2, 3]
      ]
    >

The `:axes` option controls which dimensions the indexes point to,
this can be useful, for example, to access columns instead of rows.
Note can also access the same index several times:

    iex> t = Nx.tensor([[1, 2, 3], [4, 5, 6]])
    iex> Nx.gather(t, Nx.tensor([[1], [0], [2], [1]]), axes: [1])
    #Nx.Tensor<
      s32[4][2]
      [
        [2, 5],
        [1, 4],
        [3, 6],
        [2, 5]
      ]
    >

The overall output shape will have the format of the indices shape
(except the last element) followed by all non-indexed dimensions of
the tensor. Here is a more complex example:

    iex> t = Nx.iota({2, 1, 3})
    iex> Nx.gather(t, Nx.tensor([[[1], [0], [2]]]), axes: [2])
    #Nx.Tensor<
      s32[1][3][2][1]
      [
        [
          [
            [1],
            [4]
          ],
          [
            [0],
            [3]
          ],
          [
            [2],
            [5]
          ]
        ]
      ]
    >

## Vectorized tensors

`tensor` and `indices` have their vectorized axes broadcast together,
and then the operation takes place normally, with `:axis` and `indices`
having their values in reference to the input shape.

    iex> t = Nx.tensor([[[1, 2], [11, 12]], [[101, 102], [111, 112]]]) |> Nx.vectorize(:x)
    iex> idx = Nx.tensor([[[0, 0], [0, 1]], [[1, 0], [1, 1]]]) |> Nx.vectorize(:x)
    iex> Nx.gather(t, idx)
    #Nx.Tensor<
      vectorized[x: 2]
      s32[2]
      [
        [1, 2],
        [111, 112]
      ]
    >

And with vectorized broadcasting:

    iex> t = Nx.tensor([[[1, 2], [11, 12]], [[101, 102], [111, 112]]]) |> Nx.vectorize(:x)
    iex> idx = Nx.tensor([[[0, 0], [0, 1]], [[1, 0], [1, 1]]]) |> Nx.vectorize(:y)
    iex> Nx.gather(t, idx)
    #Nx.Tensor<
      vectorized[x: 2][y: 2]
      s32[2]
      [
        [
          [1, 2],
          [11, 12]
        ],
        [
          [101, 102],
          [111, 112]
        ]
      ]
    >

## Error cases

    iex> Nx.gather(Nx.tensor([[1, 2], [3, 4]]), Nx.tensor([[0, 0]], type: :f32))
    ** (ArgumentError) indices must be an integer tensor, got {:f, 32}

    iex> Nx.gather(Nx.iota({3}), Nx.tensor(0))
    ** (ArgumentError) expected indices rank to be at least 1, got: 0

## concatenate/2

Concatenates tensors along the given axis.

Tensors can be a tuple or any `Nx.Container` or `Nx.LazyContainer`.
This means you can easily concatenate all columns in a dataframe
and other data structures. For convenience, this function also allows
a list of tensors to be given, which may be common outside of `defn`.

If no axis is provided, defaults to 0. All tensors must have the same
rank and all of their axis except the concatenated one must match.

If tensors with mixed types are given, the types will
be merged to a higher type and all of the tensors will
be cast to the higher type before concatenating.
If tensors are named, the names must match.

## Examples

Giving a single tensor is a no-op:

    iex> Nx.concatenate([Nx.tensor([1, 2, 3])])
    #Nx.Tensor<
      s32[3]
      [1, 2, 3]
    >

Multiple tensors are concatented:

    iex> Nx.concatenate([Nx.tensor([1, 2, 3]), Nx.tensor([4, 5, 6])])
    #Nx.Tensor<
      s32[6]
      [1, 2, 3, 4, 5, 6]
    >

Types are merged and names must match:

    iex> t1 = Nx.iota({2, 2, 2}, names: [:x, :y, :z], type: :f32)
    iex> t2 = Nx.iota({1, 2, 2}, names: [:x, :y, :z], type: :u8)
    iex> t3 = Nx.iota({1, 2, 2}, names: [:x, :y, :z], type: :s64)
    iex> Nx.concatenate([t1, t2, t3], axis: :x)
    #Nx.Tensor<
      f32[x: 4][y: 2][z: 2]
      [
        [
          [0.0, 1.0],
          [2.0, 3.0]
        ],
        [
          [4.0, 5.0],
          [6.0, 7.0]
        ],
        [
          [0.0, 1.0],
          [2.0, 3.0]
        ],
        [
          [0.0, 1.0],
          [2.0, 3.0]
        ]
      ]
    >

And you can pick a different axis:

    iex> t1 = Nx.iota({1, 3, 2}, names: [:x, :y, :z])
    iex> t2 = Nx.iota({1, 1, 2}, names: [:x, :y, :z])
    iex> t3 = Nx.iota({1, 2, 2}, names: [:x, :y, :z])
    iex> Nx.concatenate([t1, t2, t3], axis: :y)
    #Nx.Tensor<
      s32[x: 1][y: 6][z: 2]
      [
        [
          [0, 1],
          [2, 3],
          [4, 5],
          [0, 1],
          [0, 1],
          [2, 3]
        ]
      ]
    >

You can also pass any container (or lazy container) as first argument
and they are recursively traversed:

    iex> Nx.concatenate({Nx.tensor([1, 2]), {Nx.tensor([3, 4]), Nx.tensor([5, 6])}})
    #Nx.Tensor<
      s32[6]
      [1, 2, 3, 4, 5, 6]
    >

## Vectorized tensors

If vectorized tensors are given, they are all broadcasted throughout the
vectorized axes before concatenation. Normal concatenation rules still apply
to the inner shapes.

    iex> x = Nx.tensor([[1, 2]]) |> Nx.vectorize(:x)
    iex> y = Nx.tensor([[3, 4], [5, 6]]) |> Nx.vectorize(:y)
    iex> z = Nx.tensor([[10], [11]]) |> Nx.vectorize(:x)
    iex> Nx.concatenate({x, y, z})
    #Nx.Tensor<
      vectorized[x: 2][y: 2]
      s32[5]
      [
        [
          [1, 2, 3, 4, 10],
          [1, 2, 5, 6, 10]
        ],
        [
          [1, 2, 3, 4, 11],
          [1, 2, 5, 6, 11]
        ]
      ]
    >

## Error cases

Shapes must have the same rank and match on the non-concatenating axis.

For example, the tensors below work if we concatenate on axis 1, but not on axis 0:

    iex> t1 = Nx.iota({1, 2, 3})
    iex> t2 = Nx.iota({1, 1, 3})
    iex> result = Nx.concatenate([t1, t2], axis: 1)
    iex> Nx.shape(result)
    {1, 3, 3}
    iex> Nx.concatenate([t1, t2], axis: 0)
    ** (ArgumentError) expected all shapes to match {*, 2, 3}, got unmatching shape: {1, 1, 3}

If the ranks are different, it doesn't work, regardless of the axis choice:

    iex> t1 = Nx.iota({1, 2, 3})
    iex> t2 = Nx.iota({1, 1})
    iex> Nx.concatenate([t1, t2])
    ** (ArgumentError) expected all shapes to match {*, 2, 3}, got unmatching shape: {1, 1}

## stack/2

Stacks a list of tensors with the same shape along a new axis.

Tensors can be a tuple or any `Nx.Container` or `Nx.LazyContainer`.
This means you can easily concatenate all columns in a dataframe
and other data structures. For convenience, this function also allows
a list of tensors to be given, which may be common outside of `defn`.

If no axis is provided, defaults to 0. All tensors must have the same
shape.

If tensors with mixed types are given, the types will
be merged to a higher type and all of the tensors will
be cast to the higher type before concatenating.
If tensors are named, the names must match.

### Options

  * `:axis` - optional index of the axis along which the tensors are stacked. Defaults to 0.
  * `:name` - optional name for the added dimension. Defaults to an unnamed axis.

## Examples

Stacking always creates a new dimension:

    iex> Nx.stack([1, 2, 3])
    #Nx.Tensor<
      s32[3]
      [1, 2, 3]
    >

    iex> Nx.stack([Nx.tensor([1, 2, 3]), Nx.tensor([4, 5, 6])])
    #Nx.Tensor<
      s32[2][3]
      [
        [1, 2, 3],
        [4, 5, 6]
      ]
    >

The axis option can be given:

    iex> t1 = Nx.iota({2, 1, 4})
    iex> t2 = Nx.iota({2, 1, 4})
    iex> t3 = Nx.iota({2, 1, 4})
    iex> Nx.stack([t1, t2, t3], axis: -1)
    #Nx.Tensor<
      s32[2][1][4][3]
      [
        [
          [
            [0, 0, 0],
            [1, 1, 1],
            [2, 2, 2],
            [3, 3, 3]
          ]
        ],
        [
          [
            [4, 4, 4],
            [5, 5, 5],
            [6, 6, 6],
            [7, 7, 7]
          ]
        ]
      ]
    >

And a name can be given for the new dimension:

    iex> Nx.stack([Nx.tensor(1), Nx.tensor(2)], name: :x)
    #Nx.Tensor<
      s32[x: 2]
      [1, 2]
    >

You can also pass any container (or lazy container) as first argument
and they are recursively traversed:

    iex> Nx.stack({Nx.tensor([1, 2]), {Nx.tensor([3, 4]), Nx.tensor([5, 6])}})
    #Nx.Tensor<
      s32[3][2]
      [
        [1, 2],
        [3, 4],
        [5, 6]
      ]
    >

## sort/2

Sorts the tensor along the given axis according
to the given direction.

If no axis is given, defaults to `0`.

### Options

  * `:axis` - The name or number of the corresponding axis on which the sort
    should be applied
  * `:direction` - Can be `:asc` or `:desc`. Defaults to `:asc`
  * `:stable` - If the sorting is stable. Defaults to `false`

## Examples

    iex> Nx.sort(Nx.tensor([16, 23, 42, 4, 8, 15]))
    #Nx.Tensor<
      s32[6]
      [4, 8, 15, 16, 23, 42]
    >

    iex> t = Nx.tensor([[3, 1, 7], [2, 5, 4]], names: [:x, :y])
    iex> Nx.sort(t, axis: :x)
    #Nx.Tensor<
      s32[x: 2][y: 3]
      [
        [2, 1, 4],
        [3, 5, 7]
      ]
    >

    iex> t = Nx.tensor([[3, 1, 7], [2, 5, 4]], names: [:x, :y])
    iex> Nx.sort(t, axis: :y)
    #Nx.Tensor<
      s32[x: 2][y: 3]
      [
        [1, 3, 7],
        [2, 4, 5]
      ]
    >

    iex> t = Nx.tensor([[3, 1, 7], [2, 5, 4]], names: [:x, :y])
    iex> Nx.sort(t, axis: :y, direction: :asc)
    #Nx.Tensor<
      s32[x: 2][y: 3]
      [
        [1, 3, 7],
        [2, 4, 5]
      ]
    >

    iex> t = Nx.tensor(
    ...>   [
    ...>     [[4, 5], [2, 5], [5, 0]],
    ...>     [[1, 9], [2, 1], [2, 1]],
    ...>     [[0, -1], [-1, 0], [0, -1]],
    ...>     [[-1, 0], [0, -1], [-1, 0]]
    ...>   ],
    ...>   names: [:x, :y, :z]
    ...> )
    iex> Nx.sort(t, axis: :x)
    #Nx.Tensor<
      s32[x: 4][y: 3][z: 2]
      [
        [
          [-1, -1],
          [-1, -1],
          [-1, -1]
        ],
        [
          [0, 0],
          [0, 0],
          [0, 0]
        ],
        [
          [1, 5],
          [2, 1],
          [2, 0]
        ],
        [
          [4, 9],
          [2, 5],
          [5, 1]
        ]
      ]
    >

Same tensor sorted over different axes:

    iex> t = Nx.tensor(
    ...>   [
    ...>     [
    ...>       [4, 5, 2],
    ...>       [2, 5, 3],
    ...>       [5, 0, 2]
    ...>     ],
    ...>     [
    ...>       [1, 9, 8],
    ...>       [2, 1, 3],
    ...>       [2, 1, 4]
    ...>     ]
    ...>   ],
    ...>   names: [:x, :y, :z]
    ...> )
    iex> Nx.sort(t, axis: :x)
    #Nx.Tensor<
      s32[x: 2][y: 3][z: 3]
      [
        [
          [1, 5, 2],
          [2, 1, 3],
          [2, 0, 2]
        ],
        [
          [4, 9, 8],
          [2, 5, 3],
          [5, 1, 4]
        ]
      ]
    >
    iex> Nx.sort(t, axis: :y)
    #Nx.Tensor<
      s32[x: 2][y: 3][z: 3]
      [
        [
          [2, 0, 2],
          [4, 5, 2],
          [5, 5, 3]
        ],
        [
          [1, 1, 3],
          [2, 1, 4],
          [2, 9, 8]
        ]
      ]
    >
    iex> Nx.sort(t, axis: :z)
    #Nx.Tensor<
      s32[x: 2][y: 3][z: 3]
      [
        [
          [2, 4, 5],
          [2, 3, 5],
          [0, 2, 5]
        ],
        [
          [1, 8, 9],
          [1, 2, 3],
          [1, 2, 4]
        ]
      ]
    >

When it comes to NaN and infinities, NaN always sorts higher than
everything else:

    iex> t = Nx.tensor([:nan, :neg_infinity, 0.0, :infinity])
    iex> Nx.sort(t)
    #Nx.Tensor<
      f32[4]
      [-Inf, 0.0, Inf, NaN]
    >
    iex> Nx.sort(t, direction: :desc)
    #Nx.Tensor<
      f32[4]
      [NaN, Inf, 0.0, -Inf]
    >

## top_k/2

Returns a tuple of `{values, indices}` for the top `k`
values in last dimension of the tensor.

`:k` is an option and must be at least 1, and less than
or equal to the size of the last dimension of the tensor.
It defaults to `1`.

## Examples

    iex> a = Nx.tensor([1, 2, 3, 4, 5])
    iex> {values, indices} = Nx.top_k(a, k: 2)
    iex> values
    #Nx.Tensor<
      s32[2]
      [5, 4]
    >
    iex> indices
    #Nx.Tensor<
      s32[2]
      [4, 3]
    >

`:k` defaults to 1:

    iex> a = Nx.tensor([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]])
    iex> {values, indices} = Nx.top_k(a)
    iex> values
    #Nx.Tensor<
      f32[2][1]
      [
        [3.0],
        [6.0]
      ]
    >
    iex> indices
    #Nx.Tensor<
      s32[2][1]
      [
        [2],
        [2]
      ]
    >

When it comes to NaN and infinities, NaN always sorts higher than
everything else:

    iex> t = Nx.tensor([:nan, :neg_infinity, :infinity, 0.0])
    iex> {values, indices} = Nx.top_k(t, k: 3)
    iex> values
    #Nx.Tensor<
      f32[3]
      [NaN, Inf, 0.0]
    >
    iex> indices
    #Nx.Tensor<
      s32[3]
      [0, 2, 3]
    >

## Error cases

    iex> a = Nx.tensor([1, 2, 3, 4, 5])
    iex> Nx.top_k(a, k: 6)
    ** (ArgumentError) top_k input last axis size must be greater than or equal to k, got size=5 and k=6

    iex> a = Nx.tensor(1)
    iex> Nx.top_k(a, k: 1)
    ** (ArgumentError) top_k input must have at least rank 1

## argsort/2

Sorts the tensor along the given axis according
to the given direction and returns the corresponding indices
of the original tensor in the new sorted positions.

If no axis is given, defaults to `0`.

See `take_along_axis/3` for examples on how to apply the
resulting indices from this function.

## Options

  * `:axis` - The name or number of the corresponding axis on which the sort
    should be applied
  * `:direction` - Can be `:asc` or `:desc`. Defaults to `:asc`
  * `:stable` - If the sorting is stable. Defaults to `false`
  * `:type` - The type of the resulting tensor. Defaults to `:s32`.

## Examples

    iex> Nx.argsort(Nx.tensor([16, 23, 42, 4, 8, 15]))
    #Nx.Tensor<
      s32[6]
      [3, 4, 5, 0, 1, 2]
    >

    iex> t = Nx.tensor([[3, 1, 7], [2, 5, 4]], names: [:x, :y])
    iex> Nx.argsort(t, axis: :x)
    #Nx.Tensor<
      s32[x: 2][y: 3]
      [
        [1, 0, 1],
        [0, 1, 0]
      ]
    >

    iex> t = Nx.tensor([[3, 1, 7], [2, 5, 4]], names: [:x, :y])
    iex> Nx.argsort(t, axis: :y)
    #Nx.Tensor<
      s32[x: 2][y: 3]
      [
        [1, 0, 2],
        [0, 2, 1]
      ]
    >

    iex> t = Nx.tensor([[3, 1, 7], [2, 5, 4]], names: [:x, :y])
    iex> Nx.argsort(t, axis: :y, direction: :asc, type: :u32)
    #Nx.Tensor<
      u32[x: 2][y: 3]
      [
        [1, 0, 2],
        [0, 2, 1]
      ]
    >

Same tensor sorted over different axes. In this case,
we pass the stable option to preserve the order in case
of duplicate elements:

    iex> t = Nx.tensor(
    ...>   [
    ...>     [
    ...>       [4, 5, 2],
    ...>       [2, 5, 3],
    ...>       [5, 0, 2]
    ...>     ],
    ...>     [
    ...>       [1, 9, 8],
    ...>       [2, 1, 3],
    ...>       [2, 1, 4]
    ...>     ]
    ...>   ],
    ...>   names: [:x, :y, :z]
    ...> )
    iex> Nx.argsort(t, axis: :x, stable: true)
    #Nx.Tensor<
      s32[x: 2][y: 3][z: 3]
      [
        [
          [1, 0, 0],
          [0, 1, 0],
          [1, 0, 0]
        ],
        [
          [0, 1, 1],
          [1, 0, 1],
          [0, 1, 1]
        ]
      ]
    >
    iex> Nx.argsort(t, axis: :y, stable: true)
    #Nx.Tensor<
      s32[x: 2][y: 3][z: 3]
      [
        [
          [1, 2, 0],
          [0, 0, 2],
          [2, 1, 1]
        ],
        [
          [0, 1, 1],
          [1, 2, 2],
          [2, 0, 0]
        ]
      ]
    >

When it comes to NaN and infinities, NaN always sorts higher than
everything else:

    iex> t = Nx.tensor([:nan, :neg_infinity, :infinity, 0.0])
    iex> Nx.argsort(t)
    #Nx.Tensor<
      s32[4]
      [1, 3, 2, 0]
    >
    iex> Nx.argsort(t, direction: :desc)
    #Nx.Tensor<
      s32[4]
      [0, 2, 3, 1]
    >

## serialize/2

Serializes the given tensor or container of tensors to iodata.

You may pass any tensor or `Nx.Container` to serialization.
Opposite to other functions in this module, `Nx.LazyContainer`
cannot be serialized and they must be explicitly converted
to tensors before (that's because lazy containers do not preserve
their shape).

`opts` controls the serialization options. For example, you can choose
to compress the given tensor or container of tensors by passing a
compression level:

    Nx.serialize(tensor, compressed: 9)

Compression level corresponds to compression options in `:erlang.term_to_iovec/2`.

`iodata` is a list of binaries that can be written to any io device,
such as a file or a socket. You can ensure the result is a binary by
calling `IO.iodata_to_binary/1`.

Note: This function cannot be used in `defn`.

## Examples

    iex> a = Nx.tensor([1, 2, 3])
    iex> serialized_a = Nx.serialize(a)
    iex> Nx.deserialize(serialized_a)
    #Nx.Tensor<
      s32[3]
      [1, 2, 3]
    >

    iex> container = {Nx.tensor([1, 2, 3]), %{b: Nx.tensor([4, 5, 6])}}
    iex> serialized_container = Nx.serialize(container)
    iex> {a, %{b: b}} = Nx.deserialize(serialized_container)
    iex> a
    #Nx.Tensor<
      s32[3]
      [1, 2, 3]
    >
    iex> b
    #Nx.Tensor<
      s32[3]
      [4, 5, 6]
    >

## deserialize/2

Deserializes a serialized representation of a tensor or a container
with the given options.

It is the opposite of `Nx.serialize/2`.

Note: This function cannot be used in `defn`.

## Examples

    iex> a = Nx.tensor([1, 2, 3])
    iex> serialized_a = Nx.serialize(a)
    iex> Nx.deserialize(serialized_a)
    #Nx.Tensor<
      s32[3]
      [1, 2, 3]
    >

    iex> container = {Nx.vectorize(Nx.tensor([1, 2, 3]), :x), %{b: Nx.tensor([4, 5, 6])}}
    iex> serialized_container = Nx.serialize(container)
    iex> {a, %{b: b}} = Nx.deserialize(serialized_container)
    iex> a
    #Nx.Tensor<
      vectorized[x: 3]
      s32
      [1, 2, 3]
    >
    iex> b
    #Nx.Tensor<
      s32[3]
      [4, 5, 6]
    >

## load_numpy!/1

Loads a `.npy` file into a tensor.

An `.npy` file stores a single array created from Python's
NumPy library. This function can be useful for loading data
originally created or intended to be loaded from NumPy into
Elixir.

This function will raise if the archive or any of its contents
are invalid.

Note: This function cannot be used in `defn`.

## Examples

    "array.npy"
    |> File.read!()
    |> Nx.load_numpy!()
    #=>
    #Nx.Tensor<
      s32[3]
      [1, 2, 3]
    >

## load_numpy_archive!/1

Loads a `.npz` archive into a list of tensors.

An `.npz` file is a zipped, possibly compressed
archive containing multiple `.npy` files.

It returns a list of two elements tuples, where
the tensor name is first and the serialized tensor
is second. The list is returned in the same order
as in the archive. Use `Map.new/1` afterwards if
you want to access the list elements by name.

It will raise if the archive or any of its contents
are invalid.

Note: This function cannot be used in `defn`.

## Examples

    "archive.npz"
    |> File.read!()
    |> Nx.load_numpy_archive!()
    #=>
    [
      {"foo",
       #Nx.Tensor<
         s32[3]
         [1, 2, 3]
       >},
      {"bar",
       #Nx.Tensor<
         f64[5]
         [-1.0, -0.5, 0.0, 0.5, 1.0]
       >}
    ]

## variance/2

Finds the variance of a tensor.

The variance is the average of the squared deviations from the mean.
The mean is typically calculated as `sum(tensor) / n`, where `n` is the total
of elements. If, however, `:ddof` (delta degrees of freedom) is specified, the
divisor `n - ddof` is used instead.

## Examples

    iex> Nx.variance(Nx.tensor([[1, 2], [3, 4]]))
    #Nx.Tensor<
      f32
      1.25
    >

    iex> Nx.variance(Nx.tensor([[1, 2], [3, 4]]), ddof: 1)
    #Nx.Tensor<
      f32
      1.6666666
    >

    iex> Nx.variance(Nx.tensor([[1, 2], [3, 4]]), axes: [0])
    #Nx.Tensor<
      f32[2]
      [1.0, 1.0]
    >

    iex> Nx.variance(Nx.tensor([[1, 2], [3, 4]]), axes: [1])
    #Nx.Tensor<
      f32[2]
      [0.25, 0.25]
    >

    iex> Nx.variance(Nx.tensor([[1, 2], [3, 4]]), axes: [0], ddof: 1)
    #Nx.Tensor<
      f32[2]
      [2.0, 2.0]
    >

    iex> Nx.variance(Nx.tensor([[1, 2], [3, 4]]), axes: [1], ddof: 1)
    #Nx.Tensor<
      f32[2]
      [0.5, 0.5]
    >

### Keeping axes

    iex> Nx.variance(Nx.tensor([[1, 2], [3, 4]]), axes: [1], keep_axes: true)
    #Nx.Tensor<
      f32[2][1]
      [
        [0.25],
        [0.25]
      ]
    >

### Vectorized tensors

    iex> Nx.variance(Nx.tensor([[1, 2], [0, 4]]) |> Nx.vectorize(:x))
    #Nx.Tensor<
      vectorized[x: 2]
      f32
      [0.25, 4.0]
    >

## standard_deviation/2

Finds the standard deviation of a tensor.

The standard deviation is taken as the square root of the variance.
If the `:ddof` (delta degrees of freedom) option is given, the divisor
`n - ddof` is used to calculate the variance. See `variance/2`.

## Examples

    iex> Nx.standard_deviation(Nx.tensor([[1, 2], [3, 4]]))
    #Nx.Tensor<
      f32
      1.118034
    >

    iex> Nx.standard_deviation(Nx.tensor([[1, 2], [3, 4]]), ddof: 1)
    #Nx.Tensor<
      f32
      1.2909944
    >

    iex> Nx.standard_deviation(Nx.tensor([[1, 2], [10, 20]]), axes: [0])
    #Nx.Tensor<
      f32[2]
      [4.5, 9.0]
    >

    iex> Nx.standard_deviation(Nx.tensor([[1, 2], [10, 20]]), axes: [1])
    #Nx.Tensor<
      f32[2]
      [0.5, 5.0]
    >

    iex> Nx.standard_deviation(Nx.tensor([[1, 2], [10, 20]]), axes: [0], ddof: 1)
    #Nx.Tensor<
      f32[2]
      [6.363961, 12.727922]
    >

    iex> Nx.standard_deviation(Nx.tensor([[1, 2], [10, 20]]), axes: [1], ddof: 1)
    #Nx.Tensor<
      f32[2]
      [0.70710677, 7.071068]
    >

### Keeping axes

    iex> Nx.standard_deviation(Nx.tensor([[1, 2], [10, 20]]), keep_axes: true)
    #Nx.Tensor<
      f32[1][1]
      [
        [7.628073]
      ]
    >

### Vectorized tensors

    iex> Nx.standard_deviation(Nx.tensor([[1, 2], [0, 4]]) |> Nx.vectorize(:x))
    #Nx.Tensor<
      vectorized[x: 2]
      f32
      [0.5, 2.0]
    >

## covariance/2

A shortcut to `covariance/3` with either `opts` or `mean` as second argument.

## covariance/3

Computes the covariance matrix of the input tensor.

The covariance of two random variables X and Y is calculated as $Cov(X, Y) = \frac{1}{N}\sum_{i=0}^{N-1}{(X_i - \overline{X}) * (Y_i - \overline{Y})}$.

The tensor must be at least of rank 2, with shape `{n, d}`. Any additional
dimension will be treated as batch dimensions.

The column mean can be provided as the second argument and it must be
a tensor of shape `{..., d}`, where the batch shape is broadcastable with
that of the input tensor. If not provided, the mean is estimated using `Nx.mean/2`.

If the `:ddof` (delta degrees of freedom) option is given, the divisor `n - ddof`
is used for the sum of the products.

## Examples

    iex> Nx.covariance(Nx.tensor([[1, 2], [3, 4], [5, 6]]))
    #Nx.Tensor<
      f32[2][2]
      [
        [2.6666667, 2.6666667],
        [2.6666667, 2.6666667]
      ]
    >

    iex> Nx.covariance(Nx.tensor([[[1, 2], [3, 4], [5, 6]], [[7, 8], [9, 10], [11, 12]]]))
    #Nx.Tensor<
      f32[2][2][2]
      [
        [
          [2.6666667, 2.6666667],
          [2.6666667, 2.6666667]
        ],
        [
          [2.6666667, 2.6666667],
          [2.6666667, 2.6666667]
        ]
      ]
    >

    iex> Nx.covariance(Nx.tensor([[1, 2], [3, 4], [5, 6]]), ddof: 1)
    #Nx.Tensor<
      f32[2][2]
      [
        [4.0, 4.0],
        [4.0, 4.0]
      ]
    >

    iex> Nx.covariance(Nx.tensor([[1, 2], [3, 4], [5, 6]]), Nx.tensor([4, 3]))
    #Nx.Tensor<
      f32[2][2]
      [
        [3.6666667, 1.6666666],
        [1.6666666, 3.6666667]
      ]
    >

## fft/2

Calculates the DFT of the given tensor.

## Options

  * `:eps` - Threshold which backends can use for cleaning-up results. Defaults to `1.0e-10`.
  * `:length` - Either a positive integer or `:power_of_two`. Will pad or slice the tensor
    accordingly. `:power_of_two` will automatically pad to the next power of two.
  * `:axis` - the axis upon which the DFT will be calculated. Defaults to the last axis.

## Examples

    iex> Nx.fft(Nx.tensor([1, 1, 0, 0]))
    #Nx.Tensor<
      c64[4]
      [2.0+0.0i, 1.0-1.0i, 0.0+0.0i, 1.0+1.0i]
    >

    iex> Nx.fft(Nx.tensor([1, 1, 1, 0, 1, 1]))
    #Nx.Tensor<
      c64[6]
      [5.0+0.0i, 1.0+0.0i, -1.0+0.0i, 1.0+0.0i, -1.0+0.0i, 1.0+0.0i]
    >

The calculation can happen on a specific axis:

    iex> tensor = Nx.tensor([[1, 1, 1, 0, 1, 1], [1, 1, 1, 0, 1, 1]])
    iex> Nx.fft(tensor, axis: -1)
    #Nx.Tensor<
      c64[2][6]
      [
        [5.0+0.0i, 1.0+0.0i, -1.0+0.0i, 1.0+0.0i, -1.0+0.0i, 1.0+0.0i],
        [5.0+0.0i, 1.0+0.0i, -1.0+0.0i, 1.0+0.0i, -1.0+0.0i, 1.0+0.0i]
      ]
    >
    iex> Nx.fft(tensor, axis: -2)
    #Nx.Tensor<
      c64[2][6]
      [
        [2.0+0.0i, 2.0+0.0i, 2.0+0.0i, 0.0+0.0i, 2.0+0.0i, 2.0+0.0i],
        [0.0+0.0i, 0.0+0.0i, 0.0+0.0i, 0.0+0.0i, 0.0+0.0i, 0.0+0.0i]
      ]
    >

Padding and slicing can be introduced through `:length`:

    iex> Nx.fft(Nx.tensor([1, 1]), length: 4)
    #Nx.Tensor<
      c64[4]
      [2.0+0.0i, 1.0-1.0i, 0.0+0.0i, 1.0+1.0i]
    >

    iex> Nx.fft(Nx.tensor([1, 1, 0]), length: :power_of_two)
    #Nx.Tensor<
      c64[4]
      [2.0+0.0i, 1.0-1.0i, 0.0+0.0i, 1.0+1.0i]
    >

    iex> Nx.fft(Nx.tensor([1, 1, 0, 0, 2, 3]), length: 4)
    #Nx.Tensor<
      c64[4]
      [2.0+0.0i, 1.0-1.0i, 0.0+0.0i, 1.0+1.0i]
    >

If an N-dimensional tensor is passed, the DFT is applied, by default, to its last axis:

    iex> Nx.fft(Nx.tensor([[1, 1, 0, 0, 2, 3], [1, 0, 0, 0, 2, 3]]), length: 4)
    #Nx.Tensor<
      c64[2][4]
      [
        [2.0+0.0i, 1.0-1.0i, 0.0+0.0i, 1.0+1.0i],
        [1.0+0.0i, 1.0+0.0i, 1.0+0.0i, 1.0+0.0i]
      ]
    >

## Vectorized tensors

Vectorized tensors work the same as N-dimensional tensors

    iex> tensor = Nx.tensor([[1, 1, 0, 0, 2, 3], [1, 0, 0, 0, 2, 3]]) |> Nx.vectorize(:x)
    iex> Nx.fft(tensor, length: 4)
    #Nx.Tensor<
      vectorized[x: 2]
      c64[4]
      [
        [2.0+0.0i, 1.0-1.0i, 0.0+0.0i, 1.0+1.0i],
        [1.0+0.0i, 1.0+0.0i, 1.0+0.0i, 1.0+0.0i]
      ]
    >

## Error Cases

    iex> Nx.fft(Nx.tensor([1, 1]), length: :invalid)
    ** (RuntimeError) expected an integer or :power_of_two as length, got: :invalid

## ifft/2

Calculates the Inverse DFT of the given tensor.

## Options

  * `:eps` - Threshold which backends can use for cleaning-up results. Defaults to `1.0e-10`.
  * `:length` - Either a positive integer or `:power_of_two`. Will pad or slice the tensor
    accordingly. `:power_of_two` will automatically pad to the next power of two.
  * `:axis` - the axis upon which the Inverse DFT will be calculated. Defaults to the last axis.

## Examples

    iex> Nx.ifft(Nx.tensor([2, Complex.new(1, -1), 0, Complex.new(1, 1)]))
    #Nx.Tensor<
      c64[4]
      [1.0+0.0i, 1.0+0.0i, 0.0+0.0i, 0.0+0.0i]
    >

    iex> Nx.ifft(Nx.tensor([5, 1, -1, 1, -1, 1]))
    #Nx.Tensor<
      c64[6]
      [1.0+0.0i, 1.0+0.0i, 1.0+0.0i, 0.0+0.0i, 1.0+0.0i, 1.0+0.0i]
    >

The calculation can happen on a specific axis:

    iex> tensor = Nx.tensor([[5, 1, -1, 1, -1, 1], [5, 1, -1, 1, -1, 1]])
    iex> Nx.ifft(tensor, axis: -1)
    #Nx.Tensor<
      c64[2][6]
      [
        [1.0+0.0i, 1.0+0.0i, 1.0+0.0i, 0.0+0.0i, 1.0+0.0i, 1.0+0.0i],
        [1.0+0.0i, 1.0+0.0i, 1.0+0.0i, 0.0+0.0i, 1.0+0.0i, 1.0+0.0i]
      ]
    >
    iex> Nx.ifft(tensor, axis: -2)
    #Nx.Tensor<
      c64[2][6]
      [
        [5.0+0.0i, 1.0+0.0i, -1.0+0.0i, 1.0+0.0i, -1.0+0.0i, 1.0+0.0i],
        [0.0+0.0i, 0.0+0.0i, 0.0+0.0i, 0.0+0.0i, 0.0+0.0i, 0.0+0.0i]
      ]
    >

Padding and slicing can be introduced through `:length`:

    iex> Nx.ifft(Nx.tensor([1, 1]), length: 4)
    #Nx.Tensor<
      c64[4]
      [0.5+0.0i, 0.25+0.25i, 0.0+0.0i, 0.25-0.25i]
    >

    iex> Nx.ifft(Nx.tensor([1, 1, 0]), length: :power_of_two)
    #Nx.Tensor<
      c64[4]
      [0.5+0.0i, 0.25+0.25i, 0.0+0.0i, 0.25-0.25i]
    >

    iex> Nx.ifft(Nx.tensor([1, 1, 0, 0, 2, 3]), length: 4)
    #Nx.Tensor<
      c64[4]
      [0.5+0.0i, 0.25+0.25i, 0.0+0.0i, 0.25-0.25i]
    >

If an N-dimensional tensor is passed, the Inverse DFT is applied, by default,to its last axis:

    iex> Nx.ifft(Nx.tensor([[1, 1, 0, 0, 2, 3], [1, 0, 0, 0, 2, 3]]), length: 4)
    #Nx.Tensor<
      c64[2][4]
      [
        [0.5+0.0i, 0.25+0.25i, 0.0+0.0i, 0.25-0.25i],
        [0.25+0.0i, 0.25+0.0i, 0.25+0.0i, 0.25+0.0i]
      ]
    >

## Vectorized tensors

Vectorized tensors work the same as N-dimensional tensors

    iex> tensor = Nx.tensor([[1, 1, 0, 0, 2, 3], [1, 0, 0, 0, 2, 3]]) |> Nx.vectorize(:x)
    iex> Nx.ifft(tensor, length: 4)
    #Nx.Tensor<
      vectorized[x: 2]
      c64[4]
      [
        [0.5+0.0i, 0.25+0.25i, 0.0+0.0i, 0.25-0.25i],
        [0.25+0.0i, 0.25+0.0i, 0.25+0.0i, 0.25+0.0i]
      ]
    >

## Error Cases

    iex> Nx.ifft(Nx.tensor([1, 1]), length: :invalid)
    ** (RuntimeError) expected an integer or :power_of_two as length, got: :invalid

## fft2/2

Calculates the 2D DFT of the given tensor.

## Options

  * `:eps` - Threshold which backends can use for cleaning-up results. Defaults to `1.0e-10`.
  * `:lengths` - A 2 element list where each element is either a positive integer or `:power_of_two`.
    Will pad or slice the tensor accordingly. `:power_of_two` will automatically pad to the next power of two.
  * `:axes` - the 2 axes upon which the Inverse 2D DFT will be calculated. Defaults to the last 2 axes.

## Examples

    iex> Nx.fft2(Nx.tensor([[1, 0, 1, 0], [1, 1, 1, 1]]))
    #Nx.Tensor<
      c64[2][4]
      [
        [6.0+0.0i, 0.0+0.0i, 2.0+0.0i, 0.0+0.0i],
        [-2.0+0.0i, 0.0+0.0i, 2.0+0.0i, 0.0+0.0i]
      ]
    >

The calculation can happen on a specific pair of axes:

    iex> tensor = Nx.tensor([[[1, 0, 1, 0]], [[1, 1, 1, 1]]])
    iex> Nx.fft2(tensor, axes: [0, -1])
    #Nx.Tensor<
      c64[2][1][4]
      [
        [
          [6.0+0.0i, 0.0+0.0i, 2.0+0.0i, 0.0+0.0i]
        ],
        [
          [-2.0+0.0i, 0.0+0.0i, 2.0+0.0i, 0.0+0.0i]
        ]
      ]
    >
    iex> Nx.fft2(tensor, axes: [-2, -1])
    #Nx.Tensor<
      c64[2][1][4]
      [
        [
          [2.0+0.0i, 0.0+0.0i, 2.0+0.0i, 0.0+0.0i]
        ],
        [
          [4.0+0.0i, 0.0+0.0i, 0.0+0.0i, 0.0+0.0i]
        ]
      ]
    >

Padding and slicing can be introduced through `:lengths`:

    iex> tensor = Nx.tensor([[1, 1], [1, 0]])
    iex> Nx.fft2(tensor, lengths: [2, 4])
    #Nx.Tensor<
      c64[2][4]
      [
        [3.0+0.0i, 2.0-1.0i, 1.0+0.0i, 2.0+1.0i],
        [1.0+0.0i, 0.0-1.0i, -1.0+0.0i, 0.0+1.0i]
      ]
    >
    iex> Nx.fft2(tensor, lengths: [4, 2])
    #Nx.Tensor<
      c64[4][2]
      [
        [3.0+0.0i, 1.0+0.0i],
        [2.0-1.0i, 0.0-1.0i],
        [1.0+0.0i, -1.0+0.0i],
        [2.0+1.0i, 0.0+1.0i]
      ]
    >

    iex> Nx.fft2(Nx.tensor([[1, 1, 0], [1, 1, 0], [1, 1, -1]]), lengths: [:power_of_two, :power_of_two])
    #Nx.Tensor<
      c64[4][4]
      [
        [5.0+0.0i, 4.0-3.0i, -1.0+0.0i, 4.0+3.0i],
        [1.0-2.0i, -2.0-1.0i, 1.0+0.0i, 0.0-1.0i],
        [1.0+0.0i, 2.0-1.0i, -1.0+0.0i, 2.0+1.0i],
        [1.0+2.0i, 0.0+1.0i, 1.0+0.0i, -2.0+1.0i]
      ]
    >

    iex> Nx.fft2(Nx.tensor([[[1, 1, 0, 0, 2, 3]]]), axes: [0, 2], lengths: [2, 4])
    #Nx.Tensor<
      c64[2][1][4]
      [
        [
          [2.0+0.0i, 1.0-1.0i, 0.0+0.0i, 1.0+1.0i]
        ],
        [
          [2.0+0.0i, 1.0-1.0i, 0.0+0.0i, 1.0+1.0i]
        ]
      ]
    >

If an N-dimensional tensor is passed, the DFT is, by default, applied to the last axes:

    iex> tensor = Nx.tensor([
    ...> [[[1, 0, 1, 0, 10, 10], [1, 1, 1, 1, 10, 10]]],
    ...> [[[-2, -2, -2, -2, 20, 20], [0, 0, 0, 1, -20, -20]]]])
    iex> Nx.fft2(tensor, lengths: [2, 4])
    #Nx.Tensor<
      c64[2][1][2][4]
      [
        [
          [
            [6.0+0.0i, 0.0+0.0i, 2.0+0.0i, 0.0+0.0i],
            [-2.0+0.0i, 0.0+0.0i, 2.0+0.0i, 0.0+0.0i]
          ]
        ],
        [
          [
            [-7.0+0.0i, 0.0+1.0i, -1.0+0.0i, 0.0-1.0i],
            [-9.0+0.0i, 0.0-1.0i, 1.0+0.0i, 0.0+1.0i]
          ]
        ]
      ]
    >

## Vectorized tensors

Vectorized tensors work the same as N-dimensional tensors

    iex> tensor = Nx.tensor([
    ...> [[[1, 0, 1, 0, 10, 10], [1, 1, 1, 1, 10, 10]]],
    ...> [[[-2, -2, -2, -2, 20, 20], [0, 0, 0, 1, -20, -20]]]
    ...> ]) |> Nx.vectorize(:x)
    iex> Nx.fft2(tensor, lengths: [2, 4])
    #Nx.Tensor<
      vectorized[x: 2]
      c64[1][2][4]
      [
        [
          [
            [6.0+0.0i, 0.0+0.0i, 2.0+0.0i, 0.0+0.0i],
            [-2.0+0.0i, 0.0+0.0i, 2.0+0.0i, 0.0+0.0i]
          ]
        ],
        [
          [
            [-7.0+0.0i, 0.0+1.0i, -1.0+0.0i, 0.0-1.0i],
            [-9.0+0.0i, 0.0-1.0i, 1.0+0.0i, 0.0+1.0i]
          ]
        ]
      ]
    >

## Error Cases

    iex> Nx.fft2(Nx.tensor([[1, 1]]), lengths: [:invalid, 2])
    ** (ArgumentError) expected :lengths to be a list of lengths or :power_of_two, got: [:invalid, 2]

    iex> Nx.fft2(Nx.tensor([1, 1]), length: :invalid)
    ** (ArgumentError) expected a tensor with rank > 1, got tensor with rank 1

## ifft2/2

Calculates the Inverse 2D DFT of the given tensor.

## Options

  * `:eps` - Threshold which backends can use for cleaning-up results. Defaults to `1.0e-10`.
  * `:lengths` - A 2 element list where each element is either a positive integer or `:power_of_two`.
    Will pad or slice the tensor accordingly. `:power_of_two` will automatically pad to the next power of two.
  * `:axes` - the 2 axes upon which the Inverse 2D DFT will be calculated. Defaults to the last 2 axes.

## Examples

    iex> Nx.ifft2(Nx.tensor([[6, 0, 2, 0], [-2, 0, 2, 0]]))
    #Nx.Tensor<
      c64[2][4]
      [
        [1.0+0.0i, 0.0+0.0i, 1.0+0.0i, 0.0+0.0i],
        [1.0+0.0i, 1.0+0.0i, 1.0+0.0i, 1.0+0.0i]
      ]
    >

The calculation can happen on a specific pair of axes:

    iex> tensor = Nx.tensor([[[6, 0, 2, 0]], [[-2, 0, 2, 0]]])
    iex> Nx.ifft2(tensor, axes: [0, -1])
    #Nx.Tensor<
      c64[2][1][4]
      [
        [
          [1.0+0.0i, 0.0+0.0i, 1.0+0.0i, 0.0+0.0i]
        ],
        [
          [1.0+0.0i, 1.0+0.0i, 1.0+0.0i, 1.0+0.0i]
        ]
      ]
    >
    iex> Nx.ifft2(tensor, axes: [-2, -1])
    #Nx.Tensor<
      c64[2][1][4]
      [
        [
          [2.0+0.0i, 1.0+0.0i, 2.0+0.0i, 1.0+0.0i]
        ],
        [
          [0.0+0.0i, -1.0+0.0i, 0.0+0.0i, -1.0+0.0i]
        ]
      ]
    >

Padding and slicing can be introduced through `:lengths`:

    iex> tensor = Nx.tensor([[8, 8], [8, 0]])
    iex> Nx.ifft2(tensor, lengths: [2, 4])
    #Nx.Tensor<
      c64[2][4]
      [
        [3.0+0.0i, 2.0+1.0i, 1.0+0.0i, 2.0-1.0i],
        [1.0+0.0i, 0.0+1.0i, -1.0+0.0i, 0.0-1.0i]
      ]
    >
    iex> Nx.ifft2(tensor, lengths: [4, 2])
    #Nx.Tensor<
      c64[4][2]
      [
        [3.0+0.0i, 1.0+0.0i],
        [2.0+1.0i, 0.0+1.0i],
        [1.0+0.0i, -1.0+0.0i],
        [2.0-1.0i, 0.0-1.0i]
      ]
    >

    iex> Nx.ifft2(Nx.tensor([[16, 16, 0], [16, 16, 0], [16, 16, -16]]), lengths: [:power_of_two, :power_of_two])
    #Nx.Tensor<
      c64[4][4]
      [
        [5.0+0.0i, 4.0+3.0i, -1.0+0.0i, 4.0-3.0i],
        [1.0+2.0i, -2.0+1.0i, 1.0+0.0i, 0.0+1.0i],
        [1.0+0.0i, 2.0+1.0i, -1.0+0.0i, 2.0-1.0i],
        [1.0-2.0i, 0.0-1.0i, 1.0+0.0i, -2.0-1.0i]
      ]
    >

    iex> Nx.ifft2(Nx.tensor([[[8, 8, 0, 0, 2, 3]]]), axes: [0, 2], lengths: [2, 4])
    #Nx.Tensor<
      c64[2][1][4]
      [
        [
          [2.0+0.0i, 1.0+1.0i, 0.0+0.0i, 1.0-1.0i]
        ],
        [
          [2.0+0.0i, 1.0+1.0i, 0.0+0.0i, 1.0-1.0i]
        ]
      ]
    >

If an N-dimensional tensor is passed, the Inverse DFT is, by default, applied to the last axes:

    iex> tensor = Nx.tensor([
    ...> [[[8, 0, 8, 0, 10, 10], [8, 8, 8, 8, 10, 10]]],
    ...> [[[-16, -16, -16, -16, 20, 20], [0, 0, 0, 8, -20, -20]]]])
    iex> Nx.ifft2(tensor, lengths: [2, 4])
    #Nx.Tensor<
      c64[2][1][2][4]
      [
        [
          [
            [6.0+0.0i, 0.0+0.0i, 2.0+0.0i, 0.0+0.0i],
            [-2.0+0.0i, 0.0+0.0i, 2.0+0.0i, 0.0+0.0i]
          ]
        ],
        [
          [
            [-7.0+0.0i, 0.0-1.0i, -1.0+0.0i, 0.0+1.0i],
            [-9.0+0.0i, 0.0+1.0i, 1.0+0.0i, 0.0-1.0i]
          ]
        ]
      ]
    >

## Vectorized tensors

Vectorized tensors work the same as N-dimensional tensors

    iex> tensor = Nx.tensor([
    ...> [[[8, 0, 8, 0, 10, 10], [8, 8, 8, 8, 10, 10]]],
    ...> [[[-16, -16, -16, -16, 20, 20], [0, 0, 0, 8, -20, -20]]]
    ...> ]) |> Nx.vectorize(:x)
    iex> Nx.ifft2(tensor, lengths: [2, 4])
    #Nx.Tensor<
      vectorized[x: 2]
      c64[1][2][4]
      [
        [
          [
            [6.0+0.0i, 0.0+0.0i, 2.0+0.0i, 0.0+0.0i],
            [-2.0+0.0i, 0.0+0.0i, 2.0+0.0i, 0.0+0.0i]
          ]
        ],
        [
          [
            [-7.0+0.0i, 0.0-1.0i, -1.0+0.0i, 0.0+1.0i],
            [-9.0+0.0i, 0.0+1.0i, 1.0+0.0i, 0.0-1.0i]
          ]
        ]
      ]
    >

## Error Cases

    iex> Nx.ifft2(Nx.tensor([[1, 1]]), lengths: [:invalid, 2])
    ** (ArgumentError) expected :lengths to be a list of lengths or :power_of_two, got: [:invalid, 2]

    iex> Nx.ifft2(Nx.tensor([1, 1]), length: :invalid)
    ** (ArgumentError) expected a tensor with rank > 1, got tensor with rank 1

## rfft/2

Calculates the real-input DFT of the given tensor.

Exploits the conjugate-symmetry property of the DFT for real inputs by
computing the full FFT and returning only the non-redundant first
`floor(length / 2) + 1` frequency components along the transform axis.

## Options

  * `:eps` - Threshold which backends can use for cleaning-up results. Defaults to `1.0e-10`.
  * `:length` - Either a positive integer or `:power_of_two`. Will pad or slice the tensor
    along the transform axis accordingly. `:power_of_two` will automatically pad to the
    next power of two. Defaults to the axis size.
  * `:axis` - the axis upon which the real DFT will be calculated. Defaults to the last axis.

## Examples

    iex> Nx.rfft(Nx.tensor([1.0, 1.0, 0.0, 0.0]))
    #Nx.Tensor<
      c64[3]
      [2.0+0.0i, 1.0-1.0i, 0.0+0.0i]
    >

    iex> Nx.rfft(Nx.tensor([1.0, 1.0, 1.0, 0.0, 1.0, 1.0]))
    #Nx.Tensor<
      c64[4]
      [5.0+0.0i, 1.0+0.0i, -1.0+0.0i, 1.0+0.0i]
    >

The calculation can happen on a specific axis:

    iex> tensor = Nx.tensor([[1.0, 1.0, 0.0, 0.0], [1.0, 0.0, 0.0, 0.0]])
    iex> Nx.rfft(tensor, axis: -1)
    #Nx.Tensor<
      c64[2][3]
      [
        [2.0+0.0i, 1.0-1.0i, 0.0+0.0i],
        [1.0+0.0i, 1.0+0.0i, 1.0+0.0i]
      ]
    >
    iex> Nx.rfft(tensor, axis: -2)
    #Nx.Tensor<
      c64[2][4]
      [
        [2.0+0.0i, 1.0+0.0i, 0.0+0.0i, 0.0+0.0i],
        [0.0+0.0i, 1.0+0.0i, 0.0+0.0i, 0.0+0.0i]
      ]
    >

Padding and slicing can be introduced through `:length`:

    iex> Nx.rfft(Nx.tensor([1.0, 1.0]), length: 4)
    #Nx.Tensor<
      c64[3]
      [2.0+0.0i, 1.0-1.0i, 0.0+0.0i]
    >

    iex> Nx.rfft(Nx.tensor([1.0, 1.0, 0.0]), length: :power_of_two)
    #Nx.Tensor<
      c64[3]
      [2.0+0.0i, 1.0-1.0i, 0.0+0.0i]
    >

## Vectorized tensors

Vectorized tensors work the same as N-dimensional tensors

    iex> tensor = Nx.tensor([[1.0, 1.0, 0.0, 0.0], [1.0, 0.0, 0.0, 0.0]]) |> Nx.vectorize(:x)
    iex> Nx.rfft(tensor)
    #Nx.Tensor<
      vectorized[x: 2]
      c64[3]
      [
        [2.0+0.0i, 1.0-1.0i, 0.0+0.0i],
        [1.0+0.0i, 1.0+0.0i, 1.0+0.0i]
      ]
    >

## Error Cases

    iex> Nx.rfft(Nx.tensor([Complex.new(1, 0), Complex.new(0, 1)]))
    ** (ArgumentError) Nx.rfft/2 expects a real tensor, got type: {:c, 64}

    iex> Nx.rfft(Nx.tensor([1.0, 1.0]), length: :invalid)
    ** (ArgumentError) expected an integer or :power_of_two as length, got: :invalid

## irfft/2

Calculates the Inverse real-input DFT of the given tensor.

Reconstructs a real-valued signal from a one-sided complex spectrum produced
by `rfft/2`. The input is assumed to contain the non-redundant Hermitian half
of a spectrum of length `n` (i.e. `floor(n / 2) + 1` elements along the
transform axis). The missing conjugate-symmetric components are derived
automatically before calling `ifft/2`.

## Options

  * `:eps` - Threshold which backends can use for cleaning-up results. Defaults to `1.0e-10`.
  * `:length` - A positive integer specifying the output signal length `n`. Defaults to
    `2 * (m - 1)` where `m` is the axis size of the input, which assumes the original
    signal had even length. Pass an explicit `:length` to recover odd-length signals.
  * `:axis` - the axis upon which the Inverse real DFT will be calculated. Defaults to the
    last axis.

## Examples

    iex> Nx.irfft(Nx.tensor([2.0, Complex.new(1.0, -1.0), 0.0]))
    #Nx.Tensor<
      f32[4]
      [1.0, 1.0, 0.0, 0.0]
    >

    iex> Nx.irfft(Nx.tensor([5.0, 1.0, -1.0, 1.0]))
    #Nx.Tensor<
      f32[6]
      [1.0, 1.0, 1.0, 0.0, 1.0, 1.0]
    >

The calculation can happen on a specific axis:

    iex> tensor = Nx.tensor([[2.0, Complex.new(1.0, -1.0), 0.0], [4.0, 0.0, 0.0]])
    iex> Nx.irfft(tensor, axis: -1)
    #Nx.Tensor<
      f32[2][4]
      [
        [1.0, 1.0, 0.0, 0.0],
        [1.0, 1.0, 1.0, 1.0]
      ]
    >

An explicit `:length` recovers odd-length signals and controls input truncation:

    iex> Nx.irfft(Nx.tensor([2.0, Complex.new(1.0, -1.0), 0.0]), length: 4)
    #Nx.Tensor<
      f32[4]
      [1.0, 1.0, 0.0, 0.0]
    >

## Vectorized tensors

Vectorized tensors work the same as N-dimensional tensors

    iex> tensor = Nx.tensor([[2.0, Complex.new(1.0, -1.0), 0.0], [4.0, 0.0, 0.0]]) |> Nx.vectorize(:x)
    iex> Nx.irfft(tensor)
    #Nx.Tensor<
      vectorized[x: 2]
      f32[4]
      [
        [1.0, 1.0, 0.0, 0.0],
        [1.0, 1.0, 1.0, 1.0]
      ]
    >

## Error Cases

    iex> Nx.irfft(Nx.tensor([1.0, 1.0]), length: :invalid)
    ** (ArgumentError) expected a positive integer as length, got: :invalid

## linspace/3

Creates a tensor of shape `{n}` with linearly spaced samples between `start` and `stop`.

## Options

  * `:n` - The number of samples in the tensor.
  * `:name` - Optional name for the output axis.
  * `:type` - Optional type for the output. Defaults to `{:f, 32}`
  * `:endpoint` - Boolean that indicates whether to include `stop`
    as the last point in the output. Defaults to `true`

## Examples

    iex> Nx.linspace(5, 8, n: 5)
    #Nx.Tensor<
      f32[5]
      [5.0, 5.75, 6.5, 7.25, 8.0]
    >

    iex> Nx.linspace(0, 10, n: 5, endpoint: false, name: :x)
    #Nx.Tensor<
      f32[x: 5]
      [0.0, 2.0, 4.0, 6.0, 8.0]
    >

For integer types, the results might not be what's expected.
When `endpoint: true` (the default), the step is given by
`step = (stop - start) / (n - 1)`, which means that instead
of a step of `3` in the example below, we get a step close to
`3.42`. The results are calculated first and only cast in the
end, so that the `:endpoint` condition is respected.

    iex> Nx.linspace(0, 24, n: 8, type: {:u, 8}, endpoint: true)
    #Nx.Tensor<
      u8[8]
      [0, 3, 6, 10, 13, 17, 20, 24]
    >

    iex> Nx.linspace(0, 24, n: 8, type: {:s, 32}, endpoint: false)
    #Nx.Tensor<
      s32[8]
      [0, 3, 6, 9, 12, 15, 18, 21]
    >

One can also pass two higher order tensors with the same shape `{j, k, ...}`, in which case
the output will be of shape `{j, k, ..., n}`.

  iex> Nx.linspace(Nx.tensor([[[0, 10]]]), Nx.tensor([[[10, 100]]]), n: 10, name: :samples, type: {:u, 8})
  #Nx.Tensor<
    u8[1][1][2][samples: 10]
    [
      [
        [
          [0, 1, 2, 3, 4, 5, 6, 7, 8, 10],
          [10, 20, 30, 40, 50, 60, 70, 80, 90, 100]
        ]
      ]
    ]
  >

## Vectorized tensors

    iex> Nx.linspace(0, Nx.vectorize(Nx.tensor([10, 20]), :x), n: 5)
    #Nx.Tensor<
      vectorized[x: 2]
      f32[5]
      [
        [0.0, 2.5, 5.0, 7.5, 10.0],
        [0.0, 5.0, 10.0, 15.0, 20.0]
      ]
    >

    iex> start = Nx.vectorize(Nx.tensor([0, 1]), :x)
    iex> stop = Nx.vectorize(Nx.tensor([10, 20]), :y)
    iex> Nx.linspace(start, stop, n: 5)
    #Nx.Tensor<
      vectorized[x: 2][y: 2]
      f32[5]
      [
        [
          [0.0, 2.5, 5.0, 7.5, 10.0],
          [0.0, 5.0, 10.0, 15.0, 20.0]
        ],
        [
          [1.0, 3.25, 5.5, 7.75, 10.0],
          [1.0, 5.75, 10.5, 15.25, 20.0]
        ]
      ]
    >

    iex> start = Nx.vectorize(Nx.tensor([0, 1]), :x)
    iex> stop = Nx.vectorize(Nx.tensor([10, 10]), :x)
    iex> Nx.linspace(start, stop, n: 5)
    #Nx.Tensor<
      vectorized[x: 2]
      f32[5]
      [
        [0.0, 2.5, 5.0, 7.5, 10.0],
        [1.0, 3.25, 5.5, 7.75, 10.0]
      ]
    >

Linspace with a single point returns the start value:

    iex> Nx.linspace(0, 10, n: 1)
    #Nx.Tensor<
      f32[1]
      [0.0]
    >

## Error cases

    iex> Nx.linspace(0, 24, n: 1.0)
    ** (ArgumentError) expected n to be a non-negative integer, got: 1.0

    iex> Nx.linspace(Nx.tensor([[0, 1]]), Nx.tensor([1, 2, 3]), n: 2)
    ** (ArgumentError) expected start and stop to have the same shape. Got shapes {1, 2} and {3}

## from_pointer/5

Creates an Nx-tensor from an already-allocated memory space.

This function should be used with caution, as it can lead to segmentation faults.

The `backend` argument is either the backend module (such as `Nx.BinaryBackend`),
or a tuple of `{module, keyword()}` with specific backend configuration.
`pointer` is the corresponding value that would be returned from
a call to `get_pointer/2`.

## Options

Besides the options listed below, all other options are forwarded to the
underlying implementation.

  * `:names` - refer to `tensor/2`

## Examples

    pointer = %Nx.Pointer{kind: :local, address: 1234}
    Nx.from_pointer(MyBackend, pointer, {:s, 32}, {1, 3})
    #=> #Nx.Tensor<
    #=>   s32[1][3]
    #=>   [
    #=>     [10, 20, 30]
    #=>   ]
    #=> >

    pointer = %Nx.Pointer{kind: :ipc, handle: "some-ipc-handle"}
    Nx.from_pointer({MyBackend, some: :opt}, pointer, {:s, 32}, {1, 3}, names: [nil, :col])
    #=> #Nx.Tensor<
    #=>   s32[1][col: 3]
    #=>   [
    #=>     [10, 20, 30]
    #=>   ]
    #=> >

## to_pointer/2

Returns an `Nx.Pointer` that represents either a local pointer or an IPC handle for the given tensor.

Can be used in conjunction with `from_pointer/5` to share the same memory
for multiple tensors, as well as for interoperability with other programming
languages.

## Options

  * `:mode` - one of `:local`, `:ipc`. `:local` means the returned value
    represents a pointer internal to the current process. `:ipc` means
    the returned value represents an IPC handle that can be shared between
    processes. Defaults to `:local`.

Other options are relayed to the backend. For example, the EXLA backend
accepts `:permissions` (defaults to `0o400`, owner-read-only) to
control the file mode bits of the `shm_open` shared memory segment used
for `:ipc` mode on host clients.

## Examples

    t = Nx.u8([10, 20, 30])
    Nx.to_pointer(t, mode: :local)
    #=> %Nx.Pointer{kind: :local, address: 1234, data_size: 3, handle: nil}

    t = Nx.s32([1, 2, 3])
    Nx.to_pointer(t, mode: :ipc)
    #=> %Nx.Pointer{kind: :ipc, address: nil, data_size: 32, handle: "some-ipc-handle"}

## reflect/2

Pads a tensor of rank 1 or greater along the given axes through periodic reflections.

## Options

  * `:padding_config` - A list of tuples in the format `{pre, post}`,
    which specify the length (0 or greater) of the reflection before and
    after the tensor along a each axis.

See also: `pad/3`

## Examples

    iex> Nx.reflect(Nx.tensor([0, 1, 2]), padding_config: [{3, 1}])
    #Nx.Tensor<
      s32[7]
      [1, 2, 1, 0, 1, 2, 1]
    >

    iex> Nx.reflect(Nx.tensor([[0, 1, 2], [3, 4, 5]], names: [:x, :y]), padding_config: [{2, 0}, {2, 1}])
    #Nx.Tensor<
      s32[x: 4][y: 6]
      [
        [2, 1, 0, 1, 2, 1],
        [5, 4, 3, 4, 5, 4],
        [2, 1, 0, 1, 2, 1],
        [5, 4, 3, 4, 5, 4]
      ]
    >

## log2/1

Calculates the element-wise logarithm of a tensor with base 2.

## Examples

    iex> Nx.log2(2)
    #Nx.Tensor<
      f32
      1.0
    >

    iex> Nx.log2(Nx.tensor([1, 2, 4, 8]))
    #Nx.Tensor<
      f32[4]
      [0.0, 1.0, 2.0, 3.0]
    >

## log10/1

Calculates the element-wise logarithm of a tensor with base 10.

## Examples

    iex> Nx.log10(10)
    #Nx.Tensor<
      f32
      1.0
    >

    iex> Nx.log10(Nx.tensor([1, 10, 100, 1000]))
    #Nx.Tensor<
      f32[4]
      [0.0, 1.0, 2.0, 3.0]
    >

## log/2

Calculates the element-wise logarithm of a tensor with given `base`.

## Examples

    iex> Nx.log(2, 2)
    #Nx.Tensor<
      f32
      1.0
    >

    iex> Nx.log(Nx.tensor([3, 9, 27, 81]), 3)
    #Nx.Tensor<
      f32[4]
      [1.0, 2.0, 3.0, 4.0]
    >

## fill/3

Replaces every value in `tensor` with `value`.

The returned tensor has the same shape, names and vectorized axes
as the given one. The type will be computed based on the type of
`tensor` and `value`. You can also pass a `:type` option to change
this behaviour.

## Options

  * `:type` - sets the type of the returned tensor. If one is not
    given, it is automatically inferred based on the inputs, with
    type promotions

## Examples

    iex> tensor = Nx.iota({2, 2})
    iex> Nx.fill(tensor, 5)
    #Nx.Tensor<
      s32[2][2]
      [
        [5, 5],
        [5, 5]
      ]
    >

    iex> tensor = Nx.iota({2, 2}) |> Nx.vectorize(:x)
    iex> Nx.fill(tensor, 5)
    #Nx.Tensor<
      vectorized[x: 2]
      s32[2]
      [
        [5, 5],
        [5, 5]
      ]
    >

    iex> tensor = Nx.iota({2, 2})
    iex> Nx.fill(tensor, 5, type: :u8)
    #Nx.Tensor<
      u8[2][2]
      [
        [5, 5],
        [5, 5]
      ]
    >


### Type promotions

Type promotions should happen automatically, with the resulting type being the combination
of the `tensor` type and the `value` type.

    iex> tensor = Nx.iota({2, 2})
    iex> Nx.fill(tensor, 5.0)
    #Nx.Tensor<
      f32[2][2]
      [
        [5.0, 5.0],
        [5.0, 5.0]
      ]
    >

## sigil_MAT/2

A convenient `~MAT` sigil for building matrices (two-dimensional tensors).

## Examples

Before using sigils, you must first import them:

    import Nx, only: :sigils

Then you use the sigil to create matrices. The sigil:

    ~MAT<
      -1 0 0 1
      0 2 0 0
      0 0 3 0
      0 0 0 4
    >

Is equivalent to:

    Nx.tensor([
      [-1, 0, 0, 1],
      [0, 2, 0, 0],
      [0, 0, 3, 0],
      [0, 0, 0, 4]
    ])

If the tensor has any complex type, it defaults to c64.
If the tensor has any float type, it defaults to f32.
Otherwise, it is s64. You can specify the tensor type
as a sigil modifier:

    iex> import Nx, only: :sigils
    iex> ~MAT[0.1 0.2 0.3 0.4]f16
    #Nx.Tensor<
      f16[1][4]
      [
        [0.1, 0.2, 0.3, 0.4]
      ]
    >
    iex> ~MAT[1+1i 2-2.0i -3]
    #Nx.Tensor<
      c64[1][3]
      [
        [1.0+1.0i, 2.0-2.0i, -3.0+0.0i]
      ]
    >
    iex> ~MAT[1 Inf NaN]
    #Nx.Tensor<
      f32[1][3]
      [
        [1.0, Inf, NaN]
      ]
    >
    iex> ~MAT[1i Inf NaN]
    #Nx.Tensor<
      c64[1][3]
      [
        [0.0+1.0i, Inf+0.0i, NaN+0.0i]
      ]
    >
    iex> ~MAT[1i Inf+2i NaN-Infi]
    #Nx.Tensor<
      c64[1][3]
      [
        [0.0+1.0i, Inf+2.0i, NaN-Infi]
      ]
    >

## sigil_VEC/2

A convenient `~VEC` sigil for building vectors (one-dimensional tensors).

## Examples

Before using sigils, you must first import them:

    import Nx, only: :sigils

Then you use the sigil to create vectors. The sigil:

    ~VEC[-1 0 0 1]

Is equivalent to:

    Nx.tensor([-1, 0, 0, 1])

If the tensor has any complex type, it defaults to c64.
If the tensor has any float type, it defaults to f32.
Otherwise, it is s64. You can specify the tensor type
as a sigil modifier:

    iex> import Nx, only: :sigils
    iex> ~VEC[0.1 0.2 0.3 0.4]f16
    #Nx.Tensor<
      f16[4]
      [0.1, 0.2, 0.3, 0.4]
    >
    iex> ~VEC[1+1i 2-2.0i -3]
    #Nx.Tensor<
      c64[3]
      [1.0+1.0i, 2.0-2.0i, -3.0+0.0i]
    >
    iex> ~VEC[1 Inf NaN]
    #Nx.Tensor<
      f32[3]
      [1.0, Inf, NaN]
    >
    iex> ~VEC[1i Inf NaN]
    #Nx.Tensor<
      c64[3]
      [0.0+1.0i, Inf+0.0i, NaN+0.0i]
    >
    iex> ~VEC[1i Inf+2i NaN-Infi]
    #Nx.Tensor<
      c64[3]
      [0.0+1.0i, Inf+2.0i, NaN-Infi]
    >

## logsumexp/2

Returns the logarithm of the sum of the exponentials of tensor elements.

If the `:axes` option is given, it aggregates over
the given dimensions, effectively removing them.
`axes: [0]` implies aggregating over the highest order
dimension and so forth. If the axis is negative, then
counts the axis from the back. For example, `axes: [-1]`
will always aggregate all rows.

You may optionally set `:keep_axes` to true, which will
retain the rank of the input tensor by setting the reduced
axes to size 1.

Exponentials can be scaled before summation by multiplying
them with `:exp_scaling_factor` option. It must be of the same shape
as the input tensor or broadcastable to it.

## Examples

    iex> Nx.logsumexp(Nx.tensor([1, 2, 3, 4, 5, 6]))
    #Nx.Tensor<
      f32
      6.4561934
    >

    iex> Nx.logsumexp(Nx.tensor([1, 2, 3, 4, 5, 6]), exp_scaling_factor: 0.5)
    #Nx.Tensor<
      f32
      5.7630463
    >

    iex> t = Nx.tensor([1, 2, 3, 4, 5, 6])
    iex> a = Nx.tensor([-1, -1, -1, 1, 1, 1])
    iex> Nx.logsumexp(t, exp_scaling_factor: a)
    #Nx.Tensor<
      f32
      6.356537
    >

    iex> Nx.logsumexp(Nx.tensor([[1, 2], [3, 4], [5, 6]]))
    #Nx.Tensor<
      f32
      6.4561934
    >

### Aggregating over an axis

    iex> t = Nx.tensor([[1, 2], [3, 4], [5, 6]], names: [:x, :y])
    iex> Nx.logsumexp(t, axes: [:x])
    #Nx.Tensor<
      f32[y: 2]
      [5.1429315, 6.1429315]
    >

    iex> t = Nx.tensor([[1, 2], [3, 4], [5, 6]], names: [:x, :y])
    iex> Nx.logsumexp(t, axes: [:y])
    #Nx.Tensor<
      f32[x: 3]
      [2.3132617, 4.3132615, 6.3132615]
    >

    iex> t = Nx.tensor([[[1, 2], [3, 4]], [[5, 6], [7, 8]]], names: [:x, :y, :z])
    iex> Nx.logsumexp(t, axes: [:x, :z])
    #Nx.Tensor<
      f32[y: 2]
      [6.3314114, 8.331411]
    >

### Keeping axes

    iex> t = Nx.tensor([[[1, 2], [3, 4]], [[5, 6], [7, 8]]], names: [:x, :y, :z])
    iex> Nx.logsumexp(t, axes: [:x, :z], keep_axes: true)
    #Nx.Tensor<
      f32[x: 1][y: 2][z: 1]
      [
        [
          [6.3314114],
          [8.331411]
        ]
      ]
    >

### Vectorized tensors

    iex> t = Nx.vectorize(Nx.tensor([[1, 2], [3, 4], [5, 6]]), :x)
    iex> Nx.logsumexp(t, axes: [0], keep_axes: true)
    #Nx.Tensor<
      vectorized[x: 3]
      f32[1]
      [
        [2.3132617],
        [4.3132615],
        [6.3132615]
      ]
    >