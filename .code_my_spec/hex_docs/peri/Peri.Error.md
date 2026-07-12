# Peri.Error

Defines the structure and functions for handling validation errors in the Peri schema validation library.

The `Peri.Error` module encapsulates information about validation errors that occur during schema validation. Each error contains details about the path to the invalid data, the type of error, and any nested errors for complex or deeply nested schemas.

## Attributes

- `:message` - A human-readable message describing the error.
- `:content` - Additional information about the error, such as expected and actual values.
- `:path` - A list representing the path to the invalid data within the structure being validated.
- `:key` - The specific key or field that caused the error.
- `:errors` - A list of nested `Peri.Error` structs for detailed information about nested validation errors.

## Example

    iex> error = %Peri.Error{
    ...>   message: "Validation failed",
    ...>   content: %{expected: :string, actual: :integer},
    ...>   path: [:user, :age],
    ...>   key: :age,
    ...>   errors: [
    ...>     %Peri.Error{
    ...>       message: "Expected type string, got integer",
    ...>       content: nil,
    ...>       path: [:user, :age],
    ...>       key: :age,
    ...>       errors: nil
    ...>     }
    ...>   ]
    ...> }
    %Peri.Error{
      message: "Validation failed",
      content: %{expected: :string, actual: :integer},
      path: [:user, :age],
      key: :age,
      errors: [
        %Peri.Error{
          message: "Expected type string, got integer",
          content: nil,
          path: [:user, :age],
          key: :age,
          errors: nil
        }
      ]
    }

## Functions

- `error_to_map/1` - Converts a `Peri.Error` struct to a map, including nested errors.

## new_parent/3

Creates a new parent error with nested errors.

## Parameters

  - `path` - A list representing the path to the invalid data.
  - `key` - The specific key or field that caused the error.
  - `errors` - A list of nested `Peri.Error` structs.

## Examples

    iex> Peri.Error.new_parent([:user], :age, [%Peri.Error{message: "Invalid age"}])
    %Peri.Error{
      path: [:user, :age],
      key: :age,
      errors: [%Peri.Error{message: "Invalid age"}]
    }

## new_single/2

Creates a new single error with a formatted message and context.

## Parameters

  - `message` - A string template for the error message.
  - `context` - A list of key-value pairs to replace in the message template.

## Examples

    iex> Peri.Error.new_single("Invalid value for %{field}", [field: "age"])
    %Peri.Error{
      message: "Invalid value for age",
      content: %{field: "age"}
    }

## new_child/4

Creates a new child error with a path, key, message, and context.

## Parameters

  - `path` - A list representing the path to the invalid data.
  - `key` - The specific key or field that caused the error.
  - `message` - A string template for the error message.
  - `context` - A list of key-value pairs to replace in the message template.

## Examples

    iex> Peri.Error.new_child([:user], :age, "Invalid value for %{field}", [field: "age"])
    %Peri.Error{
      path: [:user, :age],
      key: :age,
      message: "Invalid value for age",
      content: %{field: "age"}
    }

## traverse_errors/2

Recursively walks an error or list of errors, applying the callback to each
leaf and replacing its message with the callback's return value.

Mirrors `Ecto.Changeset.traverse_errors/2`. Useful for translating template
strings into user-facing locale messages, e.g.

    Peri.Error.traverse_errors(errors, fn err ->
      Gettext.dgettext(MyAppWeb.Gettext, "errors", err.message, err.content || %{})
    end)

Returns the same error shape with translated messages. Non-string callback
results are coerced via `to_string/1`.

## summarize/1

Produces a compact, human-friendly string for a schema or type definition.

Used in error messages to avoid dumping the entire schema (which can be huge
for deeply nested or polymorphic schemas). Named schemas
(`{:schema, _, name: "..."}`) render as their name; raw maps render as a
truncated key list (`%{a, b, c, +N more}`).

## error_to_map/1

Recursively converts a `Peri.Error` struct into a map.

## Parameters

  - `error` - A `Peri.Error` struct to be transformed.

## Examples

    iex> error = %Peri.Error{
    ...>   message: "Validation failed",
    ...>   content: %{expected: :string, actual: :integer},
    ...>   path: [:user, :age],
    ...>   key: :age,
    ...>   errors: [
    ...>     %Peri.Error{
    ...>       message: "Expected type string, got integer",
    ...>       content: nil,
    ...>       path: [:user, :age],
    ...>       key: :age,
    ...>       errors: nil
    ...>     }
    ...>   ]
    ...> }
    iex> Peri.Error.error_to_map(error)
    %{
      message: "Validation failed",
      content: %{expected: :string, actual: :integer},
      path: [:user, :age],
      key: :age,
      errors: [
        %{
          message: "Expected type string, got integer",
          content: nil,
          path: [:user, :age],
          key: :age,
          errors: nil
        }
      ]
    }