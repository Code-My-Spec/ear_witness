# Coerce

Coerce allows defining coercions between data types.

These are standardized conversions of one kind of data to another.
A coercion can be defined using `defcoercion`.

The code that coercion is compiled to attempts to ensure that the result
is relatively fast (with the possibility for further optimization in the future).

Coerce does _not_ come with built-in coercions, instead allowing libraries that build on top of it
to define their own rules.

## coerce/2

Performs value coercion,

the simpler of the two values is converted into
a more complex type, and the result is returned as tuple.


## Examples

    iex> require Coerce
    iex> Coerce.defcoercion(Integer, Float) do
    iex>   def coerce(int, float) do
    iex>     {int + 0.0, float}
    iex>   end
    iex> end
    iex> Coerce.coerce(1, 2.3)
    {1.0, 2.3}
    iex> Coerce.coerce(1.4, 42)
    {1.4, 42.0}


    iex> require Coerce
    iex> Coerce.defcoercion(BitString, Atom) do
    iex>   def coerce(str, atom) do
    iex>     {str, inspect(atom)}
    iex>   end
    iex> end
    iex> Coerce.coerce("foo", Bar)
    {"foo", "Bar"}
    iex> Coerce.coerce("baz", :qux)
    {"baz", ":qux"}

## defcoercion/3

Define a coercion between two data types.

Expects two module names as the first two arguments and a `do`-block as third argument.
A `Coerc.CompileError` will be raised at compile-time if the coercion macro is called improperly.