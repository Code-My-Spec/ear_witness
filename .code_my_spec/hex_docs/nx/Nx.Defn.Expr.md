# Nx.Defn.Expr

The expression used by `Nx.Defn.Compiler`.

`Nx.Defn.Compiler` changes `Nx` default backend from `Nx.BinaryBackend`
to `Nx.Defn.Expr`. It is a struct with the following fields:

  * `:id` - a unique identifier
  * `:op` - the operation name
  * `:args` - the operation arguments
  * `:context` - the context of the expression.
    The default context is `:root`.

Convenience functions for traversing expressions and composite types
can be found in `Nx.Defn.Composite` and `Nx.Defn.Tree`.

## Syntax nodes

Most nodes are created directly via the `Nx` module and
therefore map directly to `Nx.Tensor` callbacks. However
the following syntax nodes exist:

  * `parameter(integer)`

  * `constant(number)`

  * `tensor(tensor)`

  * `metadata(expr, metadata)`

  * `elem(tuple, pos)` - created automatically from
    expression that return tuples. Note it may return
    tuples too, which means we have nested tuples

  * `fun(parameters, t, mfa)` - the `mfa` is used only for
    introspection purposes

  * `cond(clauses, otherwise)`

  * `while(initial, condition, body)`

  * `attach_token(token(%Nx.Defn.Token{}), expr)`

  * `runtime_call(out, tensor_or_container, opts, fun)`

  * `block(struct, block_args, default_expr, fun)` - `struct` is an `Nx.Block.*`
    value, `block_args` are the tensors and keyword options passed to `Nx.block/4`,
    `default_expr` is the traced default implementation, and `fun` is the block
    callback

`defn` compilers must handle said nodes accordingly.

## tensor/1

Builds an tensor expression from the given tensor.

## parameter/2

Creates a tensor expression parameter at `pos` based on the given tensor expression.

## parameter/3

Creates a tensor expression parameter at `pos` based on the given `tensor` and `context`.

## parameter/4

Creates a tensor expression parameter at `pos` with the given `context`, `type`,
`shape`, and `pos`.

## metadata/2

Creates a tensor expression metadata node wrapping the
given tensor expression.

The metadata is map. If the `inspect` key is present,
it will be used to annotate the metadata when inspected.
Otherwise the metadata node does not appear during
inspection.

## tuple/2

Creates a tuple with elements in `list` that points to tuple
expression `expr`.

`list` must be a list of tensor expressions of the same size
as the tuple expression.

## cond/2

Creates a `cond` tensor expression.

## while/5

Creates a `while` tensor expression.

## runtime_call/4

Helper for defining an :runtime_call expression node.