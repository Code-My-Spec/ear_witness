# Nx.Constants

Common constants used in computations.

This module can be used in `defn`.

The functions `e/0`, `pi/0` and `i/0` will follow the same rules as
literal constants when used inside `defn`. This means that they will
use the surrounding precision instead of defaulting to f32.

## nan/0

Returns NaN in f32.

## nan/2

Returns NaN (Not a Number).

## Options

  * `:backend` - a backend to allocate the tensor on.

## Examples

    iex> Nx.Constants.nan({:f, 8})
    #Nx.Tensor<
      f8
      NaN
    >

    iex> Nx.Constants.nan({:bf, 16})
    #Nx.Tensor<
      bf16
      NaN
    >

    iex> Nx.Constants.nan({:f, 16})
    #Nx.Tensor<
      f16
      NaN
    >

    iex> Nx.Constants.nan({:f, 32})
    #Nx.Tensor<
      f32
      NaN
    >

    iex> Nx.Constants.nan({:f, 64})
    #Nx.Tensor<
      f64
      NaN
    >

## infinity/0

Returns infinity in f32.

## infinity/2

Returns infinity.

## Options

  * `:backend` - a backend to allocate the tensor on.

## Examples

    iex> Nx.Constants.infinity({:f, 8})
    #Nx.Tensor<
      f8
      Inf
    >

    iex> Nx.Constants.infinity({:bf, 16})
    #Nx.Tensor<
      bf16
      Inf
    >

    iex> Nx.Constants.infinity({:f, 16})
    #Nx.Tensor<
      f16
      Inf
    >

    iex> Nx.Constants.infinity({:f, 32})
    #Nx.Tensor<
      f32
      Inf
    >

    iex> Nx.Constants.infinity({:f, 64})
    #Nx.Tensor<
      f64
      Inf
    >

## neg_infinity/0

Returns negative infinity in f32.

## neg_infinity/2

Returns negative infinity.

## Options

  * `:backend` - a backend to allocate the tensor on.

## Examples

    iex> Nx.Constants.neg_infinity({:f, 8})
    #Nx.Tensor<
      f8
      -Inf
    >

    iex> Nx.Constants.neg_infinity({:bf, 16})
    #Nx.Tensor<
      bf16
      -Inf
    >

    iex> Nx.Constants.neg_infinity({:f, 16})
    #Nx.Tensor<
      f16
      -Inf
    >

    iex> Nx.Constants.neg_infinity({:f, 32})
    #Nx.Tensor<
      f32
      -Inf
    >

    iex> Nx.Constants.neg_infinity({:f, 64})
    #Nx.Tensor<
      f64
      -Inf
    >

## max_finite/2

Returns a scalar tensor with the maximum finite value for the given type.

## Options

  * `:backend` - a backend to allocate the tensor on.

## Examples

    iex> Nx.Constants.max_finite({:u, 8})
    #Nx.Tensor<
      u8
      255
    >

    iex> Nx.Constants.max_finite({:s, 16})
    #Nx.Tensor<
      s16
      32767
    >

    iex> Nx.Constants.max_finite({:f, 32})
    #Nx.Tensor<
      f32
      3.4028235e38
    >

## max/2

Returns a scalar tensor with the maximum value for the given type.

It is infinity for floating point tensors.

## Options

  * `:backend` - a backend to allocate the tensor on.

## Examples

    iex> Nx.Constants.max({:u, 8})
    #Nx.Tensor<
      u8
      255
    >

    iex> Nx.Constants.max({:f, 32})
    #Nx.Tensor<
      f32
      Inf
    >

## min_finite/2

Returns a scalar tensor with the minimum finite value for the given type.

## Options

  * `:backend` - a backend to allocate the tensor on.

## Examples

    iex> Nx.Constants.min_finite({:u, 8})
    #Nx.Tensor<
      u8
      0
    >

    iex> Nx.Constants.min_finite({:s, 16})
    #Nx.Tensor<
      s16
      -32768
    >

    iex> Nx.Constants.min_finite({:f, 32})
    #Nx.Tensor<
      f32
      -3.4028235e38
    >

## min/2

Returns a scalar tensor with the minimum value for the given type.

It is negative infinity for floating point tensors.

## Options

  * `:backend` - a backend to allocate the tensor on.

## Examples

    iex> Nx.Constants.min({:u, 8})
    #Nx.Tensor<
      u8
      0
    >

    iex> Nx.Constants.min({:f, 32})
    #Nx.Tensor<
      f32
      -Inf
    >

## i/0

Returns the imaginary constant in c64.

## i/2

Returns the imaginary constant.

Accepts the same options as `Nx.tensor/2`

## Examples

    iex> Nx.Constants.i()
    #Nx.Tensor<
      c64
      0.0+1.0i
    >

    iex> Nx.Constants.i(:c128)
    #Nx.Tensor<
      c128
      0.0+1.0i
    >

## Error cases

    iex> Nx.Constants.i({:f, 32})
    ** (ArgumentError) invalid type for complex number. Expected {:c, 64} or {:c, 128}, got: {:f, 32}

## smallest_positive_normal/2

Returns a scalar tensor with the smallest positive value for the given type.

## Options

  * `:backend` - a backend to allocate the tensor on.

## Examples

    iex> Nx.Constants.smallest_positive_normal({:f, 64})
    #Nx.Tensor<
      f64
      2.2250738585072014e-308
    >

    iex> Nx.Constants.smallest_positive_normal({:f, 32})
    #Nx.Tensor<
      f32
      1.1754944e-38
    >

    iex> Nx.Constants.smallest_positive_normal({:f, 16})
    #Nx.Tensor<
      f16
      6.104e-5
    >

    iex> Nx.Constants.smallest_positive_normal(:bf16)
    #Nx.Tensor<
      bf16
      1.18e-38
    >

    iex> Nx.Constants.smallest_positive_normal(:f8)
    #Nx.Tensor<
      f8
      6e-5
    >

    iex> Nx.Constants.smallest_positive_normal({:s, 32})
    ** (ArgumentError) only floating types are supported, got: {:s, 32}

## epsilon/2

Returns a scalar with the machine epsilon for the given type.

The values are compatible with a IEEE 754 floating point standard.

## Options

  * `:backend` - a backend to allocate the tensor on.

## Examples

    iex> Nx.Constants.epsilon({:f, 64})
    #Nx.Tensor<
      f64
      2.220446049250313e-16
    >

    iex> Nx.Constants.epsilon({:f, 32})
    #Nx.Tensor<
      f32
      1.1920929e-7
    >

    iex> Nx.Constants.epsilon({:f, 16})
    #Nx.Tensor<
      f16
      9.77e-4
    >

    iex> Nx.Constants.epsilon(:bf16)
    #Nx.Tensor<
      bf16
      0.0078
    >

    iex> Nx.Constants.epsilon(:f8)
    #Nx.Tensor<
      f8
      0.25
    >

    iex> Nx.Constants.epsilon({:s, 32})
    ** (ArgumentError) only floating types are supported, got: {:s, 32}

## e/0

Returns $e$ in f32.

## e/2

Returns a scalar tensor with the value of $e$ for the given type.

## Options

  * `:backend` - a backend to allocate the tensor on.

## Examples

    iex> Nx.Constants.e({:f, 64})
    #Nx.Tensor<
      f64
      2.718281828459045
    >

    iex> Nx.Constants.e({:f, 32})
    #Nx.Tensor<
      f32
      2.7182817
    >

    iex> Nx.Constants.e({:f, 16})
    #Nx.Tensor<
      f16
      2.719
    >

    iex> Nx.Constants.e({:bf, 16})
    #Nx.Tensor<
      bf16
      2.7
    >

    iex> Nx.Constants.e({:f, 8})
    #Nx.Tensor<
      f8
      2.5
    >

    iex> Nx.Constants.e({:s, 32})
    ** (ArgumentError) only floating types are supported, got: {:s, 32}