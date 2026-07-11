# Nx.Type

Conveniences for working with types.

A type is a two-element tuple with the name and the size.
The respective sizes for the types are the following:

  * `:s` - signed integer (2, 4, 8, 16, 32, 64)
  * `:u` - unsigned integer (2, 4, 8, 16, 32, 64)
  * `:f` - float (8, 16, 32, 64)
  * `:bf` - a brain floating point (16)
  * `:c` - a complex number, represented as a pair of floats (64, 128)

Each type has an equivalent atom representation, for example
`{:s, 8}` can be expressed as `:s8`. When working with user-given
types make sure to call `normalize!/1` to get the canonical
representation.

Note: there is a special type used by the `defn` compiler
which is `{:tuple, size}`, that represents a tuple. Said types
do not appear on user code, only on compiler implementations,
and therefore are not handled by the functions in this module.

This module can be used in `defn`.

## min_finite_binary/1

Returns the minimum possible finite value for the given type.

## min_binary/1

Returns the minimum possible value for the given type.

## max_finite_binary/1

Returns the maximum possible finite value for the given type.

## max_binary/1

Returns the maximum possible value for the given type.

## nan_binary/1

Returns infinity as a binary for the given type.

## infinity_binary/1

Returns infinity as a binary for the given type.

## neg_infinity_binary/1

Returns negative infinity as a binary for the given type.

## infer/1

Infers the type of the given number.

## Examples

    iex> Nx.Type.infer(1)
    {:s, 32}
    iex> Nx.Type.infer(1.0)
    {:f, 32}
    iex> Nx.Type.infer(Complex.new(1))
    {:c, 64}

## normalize!/1

Validates and normalizes the given type tuple.

It returns the type tuple or raises.

Accepts both the tuple format and the short atom format.

## Examples

    iex> Nx.Type.normalize!({:u, 8})
    {:u, 8}

    iex> Nx.Type.normalize!(:u8)
    {:u, 8}

    iex> Nx.Type.normalize!({:u, 0})
    ** (ArgumentError) invalid numerical type: {:u, 0} (see Nx.Type docs for all supported types)

    iex> Nx.Type.normalize!({:k, 8})
    ** (ArgumentError) invalid numerical type: {:k, 8} (see Nx.Type docs for all supported types)

## to_floating/1

Converts the given type to a floating point representation
with the minimum size necessary.

Note both float and complex are floating point representations.

## Examples

    iex> Nx.Type.to_floating({:s, 8})
    {:f, 32}
    iex> Nx.Type.to_floating({:s, 32})
    {:f, 32}
    iex> Nx.Type.to_floating({:bf, 16})
    {:bf, 16}
    iex> Nx.Type.to_floating({:f, 32})
    {:f, 32}
    iex> Nx.Type.to_floating({:c, 64})
    {:c, 64}

## to_complex/1

Converts the given type to a complex representation with
the minimum size necessary.

## Examples

    iex> Nx.Type.to_complex({:s, 64})
    {:c, 64}
    iex> Nx.Type.to_complex({:bf, 16})
    {:c, 64}
    iex> Nx.Type.to_complex({:f, 32})
    {:c, 64}
    iex> Nx.Type.to_complex({:c, 64})
    {:c, 64}
    iex> Nx.Type.to_complex({:f, 64})
    {:c, 128}
    iex> Nx.Type.to_complex({:c, 128})
    {:c, 128}

## to_real/1

Converts the given type to a real number representation
with the minimum size necessary.

## Examples

    iex> Nx.Type.to_real({:s, 8})
    {:f, 32}
    iex> Nx.Type.to_real({:s, 64})
    {:f, 32}
    iex> Nx.Type.to_real({:bf, 16})
    {:bf, 16}
    iex> Nx.Type.to_real({:c, 64})
    {:f, 32}
    iex> Nx.Type.to_real({:c, 128})
    {:f, 64}
    iex> Nx.Type.to_real({:f, 32})
    {:f, 32}
    iex> Nx.Type.to_real({:f, 64})
    {:f, 64}

## to_aggregate/1

Converts the given type to an aggregation precision.

## Examples

    iex> Nx.Type.to_aggregate({:s, 8})
    {:s, 32}
    iex> Nx.Type.to_aggregate({:u, 16})
    {:u, 32}
    iex> Nx.Type.to_aggregate({:s, 64})
    {:s, 64}
    iex> Nx.Type.to_aggregate({:bf, 16})
    {:bf, 16}
    iex> Nx.Type.to_aggregate({:f, 32})
    {:f, 32}
    iex> Nx.Type.to_aggregate({:c, 64})
    {:c, 64}

## cast_number!/2

Casts the given number to type.

It does not handle overflow/underflow,
returning the number as is, but cast.

## Examples

    iex> Nx.Type.cast_number!({:u, 8}, 10)
    10
    iex> Nx.Type.cast_number!({:s, 8}, 10)
    10
    iex> Nx.Type.cast_number!({:s, 8}, -10)
    -10
    iex> Nx.Type.cast_number!({:f, 32}, 10)
    10.0
    iex> Nx.Type.cast_number!({:bf, 16}, -10)
    -10.0

    iex> Nx.Type.cast_number!({:f, 32}, 10.0)
    10.0
    iex> Nx.Type.cast_number!({:bf, 16}, -10.0)
    -10.0

    iex> Nx.Type.cast_number!({:c, 64}, 10)
    %Complex{im: 0.0, re: 10.0}

    iex> Nx.Type.cast_number!({:u, 8}, -10)
    ** (ArgumentError) cannot cast number -10 to {:u, 8}

    iex> Nx.Type.cast_number!({:s, 8}, 10.0)
    ** (ArgumentError) cannot cast number 10.0 to {:s, 8}

## merge/2

Merges the given types finding a suitable representation for both.

Types have the following precedence:

    c > f > bf > s > u

If the types are the same, they are merged to the highest size.
If they are different, the one with the highest precedence wins,
as long as the size of the `max(big, small * 2))` fits under 64
bits. Otherwise it casts to f64.

In the case of complex numbers, the maximum bit size is 128 bits
because they are composed of two floats. Float types are promoted
to c64 by default, with the exception of f64, which is promoted to
c128 so that a single component can represent an f64 number properly.

## Examples

    iex> Nx.Type.merge({:s, 8}, {:s, 8})
    {:s, 8}
    iex> Nx.Type.merge({:s, 8}, {:s, 64})
    {:s, 64}

    iex> Nx.Type.merge({:s, 8}, {:u, 8})
    {:s, 16}
    iex> Nx.Type.merge({:s, 16}, {:u, 8})
    {:s, 16}
    iex> Nx.Type.merge({:s, 8}, {:u, 16})
    {:s, 32}
    iex> Nx.Type.merge({:s, 32}, {:u, 8})
    {:s, 32}
    iex> Nx.Type.merge({:s, 8}, {:u, 32})
    {:s, 64}
    iex> Nx.Type.merge({:s, 64}, {:u, 8})
    {:s, 64}
    iex> Nx.Type.merge({:s, 8}, {:u, 64})
    {:s, 64}

    iex> Nx.Type.merge({:u, 8}, {:f, 32})
    {:f, 32}
    iex> Nx.Type.merge({:u, 64}, {:f, 32})
    {:f, 32}
    iex> Nx.Type.merge({:s, 8}, {:f, 32})
    {:f, 32}
    iex> Nx.Type.merge({:s, 64}, {:f, 32})
    {:f, 32}

    iex> Nx.Type.merge({:u, 8}, {:f, 64})
    {:f, 64}
    iex> Nx.Type.merge({:u, 64}, {:f, 64})
    {:f, 64}
    iex> Nx.Type.merge({:s, 8}, {:f, 64})
    {:f, 64}
    iex> Nx.Type.merge({:s, 64}, {:f, 64})
    {:f, 64}

    iex> Nx.Type.merge({:u, 8}, {:bf, 16})
    {:bf, 16}
    iex> Nx.Type.merge({:u, 64}, {:bf, 16})
    {:bf, 16}
    iex> Nx.Type.merge({:s, 8}, {:bf, 16})
    {:bf, 16}
    iex> Nx.Type.merge({:s, 64}, {:bf, 16})
    {:bf, 16}

    iex> Nx.Type.merge({:f, 32}, {:bf, 16})
    {:f, 32}
    iex> Nx.Type.merge({:f, 64}, {:bf, 16})
    {:f, 64}

    iex> Nx.Type.merge({:f, 16}, {:c, 64})
    {:c, 64}
    iex> Nx.Type.merge({:f, 32}, {:c, 64})
    {:c, 64}
    iex> Nx.Type.merge({:f, 64}, {:c, 64})
    {:c, 128}
    iex> Nx.Type.merge({:c, 64}, {:f, 32})
    {:c, 64}

    iex> Nx.Type.merge({:c, 64}, {:c, 64})
    {:c, 64}
    iex> Nx.Type.merge({:c, 128}, {:c, 64})
    {:c, 128}

## merge_number/2

Merges the given types with the type of a number.

We attempt to keep the original type and its size as best
as possible.

## Examples

    iex> Nx.Type.merge_number({:u, 8}, 0)
    {:u, 8}
    iex> Nx.Type.merge_number({:u, 8}, 255)
    {:u, 8}
    iex> Nx.Type.merge_number({:u, 8}, 256)
    {:u, 16}
    iex> Nx.Type.merge_number({:u, 8}, -1)
    {:s, 16}
    iex> Nx.Type.merge_number({:u, 8}, -32767)
    {:s, 16}
    iex> Nx.Type.merge_number({:u, 8}, -32768)
    {:s, 16}
    iex> Nx.Type.merge_number({:u, 8}, -32769)
    {:s, 32}

    iex> Nx.Type.merge_number({:s, 8}, 0)
    {:s, 8}
    iex> Nx.Type.merge_number({:s, 8}, 127)
    {:s, 8}
    iex> Nx.Type.merge_number({:s, 8}, -128)
    {:s, 8}
    iex> Nx.Type.merge_number({:s, 8}, 128)
    {:s, 16}
    iex> Nx.Type.merge_number({:s, 8}, -129)
    {:s, 16}
    iex> Nx.Type.merge_number({:s, 8}, 1.0)
    {:f, 32}
    iex> Nx.Type.merge_number({:u, 64}, -1337)
    {:s, 64}

    iex> Nx.Type.merge_number({:f, 32}, 1)
    {:f, 32}
    iex> Nx.Type.merge_number({:f, 32}, 1.0)
    {:f, 32}
    iex> Nx.Type.merge_number({:f, 64}, 1.0)
    {:f, 64}

## integer?/1

Returns true if the type is an integer in Elixir.

## Examples

    iex> Nx.Type.integer?({:s, 8})
    true
    iex> Nx.Type.integer?({:u, 64})
    true
    iex> Nx.Type.integer?({:f, 64})
    false

## float?/1

Returns true if the type is a float in Elixir.

## Examples

    iex> Nx.Type.float?({:f, 32})
    true
    iex> Nx.Type.float?({:bf, 16})
    true
    iex> Nx.Type.float?({:u, 64})
    false

## infinite_float?/1

Returns whether the given float type supports infinity values.

Most floating point types support infinity, but some specialized
formats like E4M3FN do not (the "FN" stands for "Finite, No infinities").

## Examples

    iex> Nx.Type.infinite_float?({:f, 32})
    true
    iex> Nx.Type.infinite_float?({:bf, 16})
    true
    iex> Nx.Type.infinite_float?({:f8_e4m3fn, 8})
    false
    iex> Nx.Type.infinite_float?({:s, 32})
    false

## complex?/1

Returns true if the type is a complex number.

## Examples

    iex> Nx.Type.complex?({:c, 64})
    true
    iex> Nx.Type.complex?({:f, 64})
    false

## to_string/1

Returns a string representation of the given type.

## Examples

    iex> Nx.Type.to_string({:s, 8})
    "s8"
    iex> Nx.Type.to_string({:s, 16})
    "s16"
    iex> Nx.Type.to_string({:s, 32})
    "s32"
    iex> Nx.Type.to_string({:s, 64})
    "s64"
    iex> Nx.Type.to_string({:u, 8})
    "u8"
    iex> Nx.Type.to_string({:u, 16})
    "u16"
    iex> Nx.Type.to_string({:u, 32})
    "u32"
    iex> Nx.Type.to_string({:u, 64})
    "u64"
    iex> Nx.Type.to_string({:f8_e4m3fn, 8})
    "f8_e4m3fn"
    iex> Nx.Type.to_string({:f, 8})
    "f8"
    iex> Nx.Type.to_string({:bf, 16})
    "bf16"
    iex> Nx.Type.to_string({:f, 64})
    "f64"

## smallest_positive_normal_binary/1

Returns the smallest positive number as a binary for the given type

## epsilon_binary/1

Returns the machine epsilon for the given type

## e_binary/1

Returns $e$ as a binary for the given type