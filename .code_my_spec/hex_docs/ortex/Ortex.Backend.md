# Ortex.Backend

Documentation for `Ortex.Backend`.

This implements the `Nx.Backend` behaviour for `Ortex` tensors. Most `Nx` operations
are not implemented for this (although they may be in the future). This is mainly
for ergonomic tensor construction and deconstruction from Ortex inputs and outputs.

Since this does not implement most `Nx` operations, it's best *NOT* to set this as
the default backend.