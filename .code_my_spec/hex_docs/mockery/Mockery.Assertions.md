# Mockery.Assertions

Additional assertion helpers for verifying calls made to mocked modules and functions in tests.

This module provides macros and functions to assert whether certain functions have been called,
how many times they have been called, and with what arguments.

> #### Important Notes {: .warning}
>
> * Mockery only tracks calls to modules prepared by `Mockery.Macro.mockable/2`.
>
> * Tracking only works when the configuration `config :mockery, enable: true` is set.
>
> * Calls made outside the test process (such as those in spawned Tasks, GenServers, etc.) are not tracked.

## assert_called!/3

Asserts that a function on the given `mod` with the given `fun` name was called.

This macro is a convenience wrapper that allows you to assert calls with
additional filtering via options.

Accepted options:
  * `:arity` - a non-negative integer narrowing the check to calls with the given arity.
  * `:args` - a list representing the argument pattern to match recorded calls.
    Use unbound variables (e.g. `_`, `var`) to create flexible patterns.
  * `:times` - how many times the function is expected to be called.
    Supports an integer, `{:in, [integers]}`, `{:in, Range.t()}`, `{:at_least, n}` and
    `{:at_most, n}`.

Notes:
  * `:arity` and `:args` are mutually exclusive. If both are provided, `:arity`
    will be ignored and a warning will be emitted.
  * If provided, `:args` must be a list — otherwise a `Mockery.Error` will be raised.
  * If provided, `:arity` must be a non-negative integer — otherwise a `Mockery.Error` will be raised.
  * If `:times` has an invalid format a `Mockery.Error` will be raised.

Returns `true` when the assertion passes. On failure it raises an error
with a descriptive message and (when history is enabled) a snippet of the recorded calls.

## Examples

    # Assert any function named :fun on Mod was called at least once
    assert_called! Mod, :fun

    # Assert Mod.fun/2 was called
    assert_called! Mod, :fun, arity: 2

    # Assert Mod.fun/2 was called with specific args (supports patterns)
    assert_called! Mod, :fun, args: ["a", _]

    # Assert Mod.fun/2 was called exactly 3 times
    assert_called! Mod, :fun, times: 3

    # Assert Mod.fun/1 was called at least twice
    assert_called! Mod, :fun, arity: 1, times: {:at_least, 2}

## refute_called!/3

Negated version of `assert_called!/3`. Asserts that the given function on the
provided `mod` with name `fun` was NOT called according to the provided options.

Supported options are the same as `assert_called!/3` (`:arity`, `:args`, `:times`).