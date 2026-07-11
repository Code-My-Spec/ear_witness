# Bunch.Module

A bunch of functions for easier manipulation on modules.

## check_behaviour/2

Determines whether module implements a behaviour by checking a test function.

Checked behaviour needs to define a callback with unique name and no arguments,
that should return `true`. This functions ensures that the module is loaded and
checks if it exports implementation of the callback that returns `true`. If
all these conditions are met, `true` is returned. Otherwise returns `false`.

## struct/1

Returns instance of struct defined in given module, if the module defines struct.
Otherwise returns `nil`.

Raises if struct has any required fields.

## loaded_and_function_exported?/3

Ensures that module is loaded and checks whether it exports given function.

## apply/4

Works like `Kernel.apply/3` if `module` exports `fun_name/length(args)`,
otherwise returns `default`.

Determines if function is exported using `loaded_and_function_exported?/3`.