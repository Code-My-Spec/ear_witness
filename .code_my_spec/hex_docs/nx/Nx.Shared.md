# Nx.Shared



## match_types/2

Match the cartesian product of all given types.

A macro that allows us to write all possible match types
in the most efficient format. This is done by looking at @0,
@1, etc., and replacing them with the currently matched type at the
given position. In other words, this:

   match_types [input_type, output_type] do
     for <<match!(seg, 0) <- data>>, into: <<>>, do: <<write!(read!(seg, 0) + right, 1)>>
   end

Is compiled into:

   for <<seg::float-native-size(...) <- data>>, into: <<>>, do: <<seg+right::float-native-size(...)>>

for all possible valid types between input and output types.

`match!` is used in matches and must always be followed by a `read!`.
`write!` is used to write to the binary.

The implementation unfolds the loops at the top level. In particular,
note that a rolled out case such as:

    for <<seg::size(^size)-signed-integer <- data>>, into: <<>> do
      <<seg+number::signed-integer-size(size)>>
    end

is twice as fast and uses half the memory compared to:

    for <<seg::size(^size)-signed-integer <- data>>, into: <<>> do
      case output_type do
        {:s, size} ->
          <<seg+number::signed-integer-size(size)>>
        {:f, size} ->
          <<seg+number::float-native-size(size)>>
        {:u, size} ->
          <<seg+number::unsigned-integer-size(size)>>
      end
    end

## read_complex/2

C64 and C128 callback.

## write_complex/3

Complex write callback.

## read_non_finite/2

Non-finite read callback.

## defnguard/2

Defines a macro that delegates to Elixir.Kernel when inside a guard.

## unary_math_funs/0

Returns the definition of mathematical unary funs.

## binary_type/2

Builds the type of an element-wise binary operation.

## tuple_append/2

Appends an element to a tuple.

## backend_from_options!/1

Extracts the backend from the given options.

## assert_keys!/2

Asserts on the given keys.

## impl!/1

Gets the implementation of a tensor.

## list_impl!/1

Gets the implementation of a list of maybe tensors.

## backend_pdict_key/0

The process dictionary key to store default backend under.