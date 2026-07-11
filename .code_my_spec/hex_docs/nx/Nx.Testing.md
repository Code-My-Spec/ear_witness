# Nx.Testing

Testing functions for Nx tensor assertions.

This module provides functions for asserting tensor equality and
approximate equality within specified tolerances.

## assert_equal/2

Asserts that two tensors are exactly equal.

This handles NaN values correctly by considering NaN == NaN as true.

## assert_all_close/3

Asserts that two tensors are approximately equal within the given tolerances.

See also:

* `Nx.all_close/2` - The underlying function that performs the comparison.

## Options

  * `:atol` - The absolute tolerance. Defaults to 1.0e-4.
  * `:rtol` - The relative tolerance. Defaults to 1.0e-4.