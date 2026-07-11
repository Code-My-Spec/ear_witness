# Nx.Backend

The behaviour for tensor backends.

Each backend is module that defines a struct and implements the callbacks
defined in this module. The callbacks are mostly implementations of the
functions in the `Nx` module with the tensor output shape given as first
argument.

`Nx` backends come in two flavors: opaque backends, of which you should
not access its data directly except through the functions in the `Nx`
module, and public ones, of which its data can be directly accessed and
traversed. The former typically have the `Backend` suffix.

`Nx` ships with the following backends:

  * `Nx.BinaryBackend` - an opaque backend written in pure Elixir
    that stores the data in Elixir's binaries. This is the default
    backend used by the `Nx` module. The backend itself (and its
    data) is private and must not be accessed directly.

  * `Nx.TemplateBackend` - an opaque backend written that works as
    a template in APIs to declare the type, shape, and names of
    tensors to be expected in the future.

  * `Nx.Defn.Expr` - a public backend used by `defn` to build
    expression trees that are traversed by custom compilers.

This module also includes functions that are meant to be shared
across backends.

## inspect/3

Inspects the given tensor given by `binary`.

Note the `binary` may have fewer elements than the
tensor size but, in such cases, it must strictly have
more elements than `inspect_opts.limit`.