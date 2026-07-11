# Bunch

A bunch of general-purpose helper and convenience functions.

## __using__/1

Imports a bunch of Bunch macros: `withl/1`, `withl/2`, `~>/2`, `~>>/2`, `quote_expr/1`, `quote_expr/2`

## key/1

Extracts the key from a key-value tuple.

## value/1

Extracts the value from a key-value tuple.

## quote_expr/2

Works like `quote/2`, but doesn't require a do/end block and options are passed
as the last argument.

Useful when quoting a single expression.

## Examples

    iex> use Bunch
    iex> quote_expr(String.t())
    quote do String.t() end
    iex> quote_expr(unquote(x) + 2, unquote: false)
    quote unquote: false do unquote(x) + 2 end

## Nesting
Nesting calls to `quote` disables unquoting in the inner call, while placing
`quote_expr` in `quote` or another `quote_expr` does not:

    iex> use Bunch
    iex> quote do quote do unquote(:code) end end == quote do quote do :code end end
    false
    iex> quote do quote_expr(unquote(:code)) end == quote do quote_expr(:code) end
    true

## stateful_try_with_status/1

Returns given stateful try value along with its status.