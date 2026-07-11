# Kino.SmartCell



## __using__/1

Invoked when the smart cell editor content changes.

Usually you just want to put the new source in the corresponding
assign.

This callback is required if the smart cell enables editor in the
`c:Kino.JS.Live.init/2` configuration.

## definitions/0

Returns a list of available smart cell definitions.

## register/1

Registers a new smart cell.

This should usually be called in `application.ex` when starting
the application.

## Examples

    Kino.SmartCell.register(KinoDocs.CustomCell)

## prefixed_var_name/2

Generates unique variable names with the given prefix.

When `var_name` is `nil`, allocates and returns the next available
name. Otherwise, marks the given suffix as taken, provided that
`var_name` has the given prefix.

This function can be used to generate default variable names during
smart cell initialization, so that don't overlap.

## valid_variable_name?/1

Checks if the given string is a valid Elixir variable name.

## quoted_to_string/1

Converts the given AST to formatted code string.