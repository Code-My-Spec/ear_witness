# Nx.Floating

Functions for loading and dumping floating-point formats
not supported by the Erlang VM.

## load_bf16/1

Loads a BF16 (Brain Float 16) value from its binary representation.

Returns a float, `:nan`, `:infinity`, or `:neg_infinity`.

## Examples

    iex> Nx.Floating.load_bf16(Nx.Floating.dump_bf16(1.0))
    1.0

    iex> Nx.Floating.load_bf16(Nx.Floating.dump_bf16(:infinity))
    :infinity

    iex> Nx.Floating.load_bf16(Nx.Floating.dump_bf16(:neg_infinity))
    :neg_infinity

## dump_bf16/1

Dumps an Elixir value to BF16 (Brain Float 16) binary representation.

## Examples

    iex> Nx.Floating.load_bf16(Nx.Floating.dump_bf16(1.0))
    1.0

    iex> Nx.Floating.load_bf16(Nx.Floating.dump_bf16(-2.5))
    -2.5

    iex> Nx.Floating.load_bf16(Nx.Floating.dump_bf16(:nan))
    :nan

## load_f8/1

Loads an F8 (E5M2) value from its binary representation.

Returns a float, `:nan`, `:infinity`, or `:neg_infinity`.

## Examples

    iex> Nx.Floating.load_f8(Nx.Floating.dump_f8(1.0))
    1.0

    iex> Nx.Floating.load_f8(Nx.Floating.dump_f8(:infinity))
    :infinity

    iex> Nx.Floating.load_f8(Nx.Floating.dump_f8(:neg_infinity))
    :neg_infinity

## dump_f8/1

Dumps an Elixir value to F8 (E5M2) binary representation.

## Examples

    iex> Nx.Floating.load_f8(Nx.Floating.dump_f8(1.0))
    1.0

    iex> Nx.Floating.load_f8(Nx.Floating.dump_f8(-2.0))
    -2.0

    iex> Nx.Floating.load_f8(Nx.Floating.dump_f8(:nan))
    :nan

## load_f8_e4m3fn/1

Loads an F8 E4M3FN value from its binary representation.

Returns a float or `:nan` (E4M3FN has no infinity).

## Examples

    iex> Nx.Floating.load_f8_e4m3fn(Nx.Floating.dump_f8_e4m3fn(1.0))
    1.0

    iex> Nx.Floating.load_f8_e4m3fn(Nx.Floating.dump_f8_e4m3fn(:nan))
    :nan

    iex> Nx.Floating.load_f8_e4m3fn(Nx.Floating.dump_f8_e4m3fn(0.0))
    0.0

    iex> Nx.Floating.load_f8_e4m3fn(Nx.Floating.dump_f8_e4m3fn(448.0))
    448.0

## dump_f8_e4m3fn/1

Dumps an Elixir value to F8 E4M3FN binary representation.

Finite values are clamped to the E4M3FN range [-448.0, 448.0].
Since E4M3FN has no infinity, `:infinity` and `:neg_infinity` saturate
to max/min finite values. Only `:nan` maps to NaN.

## Examples

    iex> Nx.Floating.dump_f8_e4m3fn(1.0)
    <<0x38>>

    iex> Nx.Floating.dump_f8_e4m3fn(0.0)
    <<0x00>>

    iex> Nx.Floating.dump_f8_e4m3fn(448.0)
    <<0x7E>>

    iex> Nx.Floating.dump_f8_e4m3fn(-448.0)
    <<0xFE>>

    iex> Nx.Floating.dump_f8_e4m3fn(:infinity)
    <<0x7E>>

    iex> Nx.Floating.dump_f8_e4m3fn(:neg_infinity)
    <<0xFE>>

    iex> Nx.Floating.dump_f8_e4m3fn(:nan)
    <<0x7F>>