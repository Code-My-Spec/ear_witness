# Nx.Defn.Compiler

The specification and helper functions for custom `defn` compilers.

## current/0

Returns the current compiler.

Returns nil if we are not inside `defn`.

## defn?/0

Returns if we are inside `defn` at _compilation time_.

This would be invoked inside a macro that has specific `defn` logic.