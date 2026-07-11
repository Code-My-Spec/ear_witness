# Nx.Ryu



## bits_to_decimal/4

Convert IEEE 754 binary representation to shortest decimal string.

Can handle any F32 format and below.

Parameters:
  - bits: the raw bit pattern as an integer
  - mantissa_bits: number of mantissa bits (e.g., 10 for f16, 23 for f32, 52 for f64)
  - exponent_bits: number of exponent bits (e.g., 5 for f16, 8 for f32, 11 for f64)
  - modifier: optional modifier atom (e.g., `:fn` for formats with no infinities
    and NaN only when all mantissa bits are 1)

Returns the shortest decimal string representation.