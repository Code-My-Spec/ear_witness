# Kino.RPC

Functions for working with remote nodes.

## eval_string/3

Evaluates the contents given by `string` on the given `node`.

Returns the value returned from evaluation.

The code is analyzed for variable references, they are automatically
extracted from the caller binding and passed to the evaluation. This
means that the evaluated string actually has closure semantics.

The code is parsed and expanded on the remote node. Also, errors
and exits are captured and propagated to the caller.

See `Code.eval_string/3` for available `opts`.