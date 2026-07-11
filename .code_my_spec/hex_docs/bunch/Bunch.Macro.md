# Bunch.Macro

A bunch of helpers for implementing macros.

## inject_calls/2

Imitates `import` functionality by finding and replacing bare function
calls (like `foo()`) in AST with fully-qualified call (like `Some.Module.foo()`)

Receives AST fragment as first parameter and
list of pairs {Some.Module, :foo} as second

## inject_call/2

Imitates `import` functionality by finding and replacing bare function
calls (like `foo()`) in AST with fully-qualified call (like `Some.Module.foo()`)

Receives AST fragment as first parameter and
a pair {Some.Module, :foo} as second

## prewalk_while/2

Works like `Macro.prewalk/2`, but allows to skip particular nodes.

## Example

    iex> code = quote do fun(1, 2, opts: [key: :val]) end
    iex> code |> Bunch.Macro.prewalk_while(fn node ->
    ...>   if Keyword.keyword?(node) do
    ...>     {:skip, node ++ [default: 1]}
    ...>   else
    ...>     {:enter, node}
    ...>   end
    ...> end)
    quote do fun(1, 2, opts: [key: :val], default: 1) end

## prewalk_while/3

Works like `Macro.prewalk/3`, but allows to skip particular nodes using an accumulator.

## Example

    iex> code = quote do fun(1, 2, opts: [key: :val]) end
    iex> code |> Bunch.Macro.prewalk_while(0, fn node, acc ->
    ...>   if Keyword.keyword?(node) do
    ...>     {:skip, node ++ [default: 1], acc + 1}
    ...>   else
    ...>     {:enter, node, acc}
    ...>   end
    ...> end)
    {quote do fun(1, 2, opts: [key: :val], default: 1) end, 1}

## expand_deep/2

Receives an AST and traverses it expanding all the nodes.

This function uses `Macro.expand/2` under the hood. Check
it out for more information and examples.