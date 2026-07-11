# Bundlex.Loader

Some utilities to ease loading of Bundlex-based NIFs.

## __using__/1

Binds the module to the specified NIF.

Accepts keyword list, that may contain two arguments:
- `:nif` - required, name of the NIF to be bound (the same as specified in `bundlex.exs`)
- `:app` - application defining the NIF, defaults to the current application

After `use`'ing this module you can utilize `defnif/1` and `defnifp/1` macros
to create bindings to particular native functions.

## Example

    defmodule My.Native.Module do
      use Bundlex.Loader, nif: :my_nif

      defnif native_function(arg1, arg2, arg3)

      def normal_function(arg1, arg2) do
        # ...
      end

      defnifp private_native_function(arg1, arg2)

    end

## defnif/1

Generates function bound to the native implementation. This module has to be
`use`d for this macro to work.

Function name should correspond to the native one.

See `__using__/1` for examples.

## defnifp/1

Works the same way as `defnif/1`, but generates private function. This module
has to be `use`d for this macro to work.

See `__using__/1` for examples.

## load_nif!/2

Binds calling module to NIF `nif_name` from application `app`.

Second argument has to be an atom, the same as name of the NIF in the bundlex
project.

Invoked internally by `__using__/1` macro, which is the preferred way of loading
NIFs.