# Nx.Defn.Tree

Helper functions to traverse defn expressions,
either as single nodes or in-depth.

## has_hooks?/2

Check if the given tree has any of the given hooks in it.

## scope_ids/2

Gets all IDs of all elements in the same scope.

`while`'s condition and body, `fun`'s body and similar are
considered different scopes. When it comes to `cond`, an ID will
only be considered if it is used outside of the `cond` or used
in several distinct conds. Constants are also ignored, as they
have global IDs based on the constants themselves.

An existing map of `ids` can be given to accumulate on top of it.

## put_args/2

Puts new args in the given tensor expression and gives it a new id.

## apply_args/4

Applies the given function to the arguments of the node,
with the given accumulator as a starting value.

By default, `type` is `:all`, which means all arguments
are traversed. If `type` is `:scope`, only expressions
that are in the same scope are traversed. Therefore,
expressions such as `while`'s condition and body,
`optional`'s default implementation, functions, and so forth
are not traversed. Note `cond`s are always traversed because,
while they introduce a new scope, they can also access its
parents directly, so you must take `cond`s into account
accordingly.

Warning: be very careful when using this function to traverse
the expression recursively. If you plan to do so, you should
consider also storing the visited nodes to avoid multiple
traversals by using `tensor.data.expr.id` as cache key.