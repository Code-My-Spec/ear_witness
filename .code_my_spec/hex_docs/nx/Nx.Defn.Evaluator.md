# Nx.Defn.Evaluator

The default implementation of a `Nx.Defn.Compiler`
that evaluates the expression tree against the
tensor backend.

## Options

The following options are specific to this compiler:

  * `:garbage_collect` - when true, garbage collects
    after evaluating each node

  * `:max_concurrency` - the number of partitions to
    start when running a `Nx.Serving` with this compiler