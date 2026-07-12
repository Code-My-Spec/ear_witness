# Peri

Peri is a schema validation library for Elixir, inspired by Clojure's Plumatic Schema.
It provides a flexible and powerful way to define and validate data structures using schemas.
The library supports nested schemas, optional fields, custom validation functions, and various type constraints.

## Key Features

- **Simple and Nested Schemas**: Define schemas that can handle complex, nested data structures.
- **Optional and Required Fields**: Specify fields as optional or required with type constraints.
- **Custom Validation Functions**: Use custom functions to validate fields.
- **Comprehensive Error Handling**: Provides detailed error messages for validation failures.
- **Type Constraints**: Supports various types including enums, lists, maps, tuples, literals, and more.

## Usage

To define a schema, use the `defschema` macro. By default, all fields in the schema are optional unless specified otherwise.

```elixir
defmodule MySchemas do
  import Peri

  defschema :user, %{
    name: :string,
    age: :integer,
    email: {:required, :string},
    address: %{
      street: :string,
      city: :string
    },
    tags: {:list, :string},
    role: {:enum, [:admin, :user, :guest]},
    geolocation: {:tuple, [:float, :float]},
    preferences: {:map, :string},
    scores: {:map, :string, :integer},
    status: {:literal, :active},
    rating: {:custom, &validate_rating/1}
  }

  defp validate_rating(n) when n < 10, do: :ok
  defp validate_rating(_), do: {:error, "invalid rating", []}
end
```

You can then use the schema to validate data:

```elixir
user_data = %{
  name: "John", age: 30, email: "john@example.com",
  address: %{street: "123 Main St", city: "Somewhere"},
  tags: ["science", "funky"], role: :admin,
  geolocation: {12.2, 34.2},
  preferences: %{"theme" => "dark", "notifications" => "enabled"},
  scores: %{"math" => 95, "science" => 92},
  status: :active,
  rating: 9
}

case MySchemas.user(user_data) do
  {:ok, valid_data} -> IO.puts("Data is valid!")
  {:error, errors} -> IO.inspect(errors, label: "Validation errors")
end
```

## Error Handling

Peri provides detailed error messages that include the path to the invalid data, the expected and actual values, and custom error messages for custom validations.

## Schema Types

Peri supports the following schema types:

- `:string`, `:integer`, `:float`, `:boolean`, `:atom`, `:map`, `:pid` - Basic types
- `{:required, type}` - Mark a field as required
- `{:list, type}` - List of elements of the given type
- `{:map, type}` - Map with values of the given type
- `{:map, key_type, value_type}` - Map with keys and values of specified types
- `{:schema, schema}` - Explicitly tagged nested schema
- `{:schema, map_schema, {:additional_keys, type}}` - Nested schema map, with extra entries validated using another type
- `{:tuple, [type1, type2, ...]}` - Tuple with elements of specified types
- `{:enum, [value1, value2, ...]}` - One of the specified values
- `{:enum, [value1, value2, ...], opts}` - Enum with opts (`:type`, `:error`, `:gen`); `:type` constrains members to a base type and surfaces it in JSON Schema output
- `{:literal, value}` - Exactly matches the specified value
- `{:either, {type1, type2}}` - Either type1 or type2
- `{:oneof, [type1, type2, ...]}` - One of the specified types
- `{:cond, condition, true_type, false_type}` - Conditional validation based on callback
- `{:dependent, callback}` - Dynamic type based on callback result
- `{:meta, type, opts}` - Attach documentation/example/description to a field; passthrough at validation
- Nested maps for complex structures

## Custom Error Messages

Override the default validation message per field via the `error:` opt in the
type's options list. Accepts either a static string or an MFA tuple
`{module, function, args}`. The MFA receives the `%Peri.Error{}` (with its
`content`) prepended to `args` and must return a string.

```elixir
%{
  age:   {:integer, gte: 18, error: "must be adult"},
  email: {:required, :string, [error: {MyApp.Errors, :email_msg, []}]}
}
```

For i18n / Gettext, walk the resulting errors with
`Peri.Error.traverse_errors/2` and translate each leaf message — see that
function's docs for an example.

## Schema Metadata

Fields can carry metadata via the `{:meta, type, opts}` wrapper. Metadata is
ignored at validation time but available for documentation, JSON Schema
export, and tooling. The JSON Schema encoder recognises the standard
Draft-7 annotation/format vocabulary (`:title`, `:description`, `:example`,
`:examples`, `:deprecated`, `:default`, `:format`, `:pattern`, `:read_only`,
`:write_only`, `:content_encoding`, `:content_media_type`); other keys
(e.g. `:doc`) are preserved opaquely for non-encoder tooling.

```elixir
defschema :user, %{
  email: {:meta, {:required, :string}, doc: "Login email", example: "a@b.io"},
  age: {:meta, {:integer, gte: 0}, description: "Years"}
}, title: "User", description: "Account holder"
```

Schema-level meta opts are exposed via the generated `__schema_meta__/1`
function. Validation opts (e.g. `:mode`) are split out, not surfaced as meta.

## Callback Functions for :cond and :dependent

Both `:cond` and `:dependent` types support 1-arity and 2-arity callbacks:

- **1-arity callbacks** receive the root data structure (backward compatible)
- **2-arity callbacks** receive `(current, root)` where:
  - `current` is the data at the current validation context (e.g., list element)
  - `root` is the entire root data structure

This is especially useful when validating elements within lists:

```elixir
defschema :parent, %{
  items: {:list, %{
    type: :string,
    value: {:dependent, fn current, _root ->
      case current.type do
        "number" -> {:ok, :integer}
        "text" -> {:ok, :string}
        _ -> {:ok, :any}
      end
    end}
  }}
}
```

## Custom Generators

When data generation matters (`Peri.generate/1`), constrained types like
`{:integer, gt: 1_000_000}` or `{:string, {:regex, …}}` fall back to
rejection sampling, which can be slow on tight domains. Provide a `gen:`
opt with an MFA, `{mod, fun}`, or 0-arity function returning
`%StreamData{}` to skip rejection entirely. Accepted in multi-options,
`{:required, type, opts}`, and `{:meta, type, opts}` positions.

    %{
      age:   {:integer, gte: 18, gen: {MyApp.Gens, :age, []}},
      email: {:meta, :string, doc: "Login", gen: {MyApp.Gens, :email}}
    }

## Schema Transformation

`Peri.walk/2` runs a depth-first rewrite over a schema, useful for
derivations like "make every field optional" or "strip private keys from a
public DTO". The callback receives `{:field, key, value}` for entries
inside a map/keyword schema and the type expression itself everywhere
else; return `{:cont, _}` to continue or `:drop` to remove a field. See
`Peri.Walker` for full semantics.

    Peri.walk(schema, fn
      {:required, t} -> {:cont, t}
      other -> {:cont, other}
    end)

## Functions

- `validate/2` - Validates data against a schema.
- `conforms?/2` - Checks if data conforms to a schema.
- `validate_schema/1` - Validates the schema definition.
- `generate/1` - Generates sample data based on schema (when StreamData is available).
- `walk/2` - Depth-first rewrite of a schema tree.

## Example

```elixir
defmodule MySchemas do
  import Peri

  defschema :user, %{
    name: :string,
    age: :integer,
    email: {:required, :string}
  }
end

user_data = %{name: "John", age: 30, email: "john@example.com"}
case MySchemas.user(user_data) do
  {:ok, valid_data} -> IO.puts("Data is valid!")
  {:error, errors} -> IO.inspect(errors, label: "Validation errors")
end
```

## defschema/3

Defines a schema with a given name and schema definition.

## Examples

    defmodule MySchemas do
      import Peri

      defschema :user, %{
        name: :string,
        age: :integer,
        email: {:required, :string}
      }

      # With permissive mode
      defschema :flexible_user, %{
        name: :string,
        email: {:required, :string}
      }, mode: :permissive

      # With metadata (field-level and schema-level)
      defschema :documented_user, %{
        email: {:meta, {:required, :string}, doc: "Login email", example: "a@b.io"}
      }, title: "User", description: "Account holder"
    end

    # Schema-level metadata is accessible via __schema_meta__/1:
    MySchemas.__schema_meta__(:documented_user)
    # => [title: "User", description: "Account holder"]

    user_data = %{name: "John", age: 30, email: "john@example.com"}
    MySchemas.user(user_data)
    # => {:ok, %{name: "John", age: 30, email: "john@example.com"}}

    invalid_data = %{name: "John", age: 30}
    MySchemas.user(invalid_data)
    # => {:error, [email: "is required"]}

    # Permissive mode preserves extra fields
    flexible_data = %{name: "John", email: "john@example.com", role: "admin"}
    MySchemas.flexible_user(flexible_data)
    # => {:ok, %{name: "John", email: "john@example.com", role: "admin"}}

## conforms?/3

Checks if the given data conforms to the specified schema.

## Parameters

  - `schema`: The schema definition to validate against.
  - `data`: The data to be validated.

## Options

  - `:mode` - Validation mode. Can be `:strict` (default) or `:permissive`.
    - `:strict` - Only fields defined in the schema are returned.
    - `:permissive` - All fields from the input data are preserved.

## Returns

  - `true` if the data conforms to the schema.
  - `false` if the data does not conform to the schema.

## Examples

    iex> schema = %{name: :string, age: :integer}
    iex> data = %{name: "Alice", age: 30}
    iex> Peri.conforms?(schema, data)
    true

    iex> invalid_data = %{name: "Alice", age: "thirty"}
    iex> Peri.conforms?(schema, invalid_data)
    false

## validate/3

Validates a given data map against a schema with options.

Returns `{:ok, data}` if the data is valid according to the schema, or `{:error, errors}` if there are validation errors.

## Parameters

  - schema: The schema definition map.
  - data: The data map to be validated.
  - opts: Options for validation.

## Options

  - `:mode` - Validation mode. Can be `:strict` (default) or `:permissive`.
    - `:strict` - Only fields defined in the schema are returned.
    - `:permissive` - All fields from the input data are preserved.

## Examples

    schema = %{name: :string, age: :integer}
    data = %{name: "John", age: 30, extra: "field"}

    # Strict mode (default)
    Peri.validate(schema, data)
    # => {:ok, %{name: "John", age: 30}}

    # Permissive mode
    Peri.validate(schema, data, mode: :permissive)
    # => {:ok, %{name: "John", age: 30, extra: "field"}}

## put_in_enum/3

Helper function to put a value into an enum, handling
not only maps and keyword lists but also structs.

## Examples

    iex> Peri.put_in_enum(%{}, :hello, "world")
    iex> Peri.put_in_enum(%{}, "hello", "world")
    iex> Peri.put_in_enum(%User{}, :hello, "world")
    iex> Peri.put_in_enum([], :hello, "world")

## validate_schema/1

Validates a schema definition to ensure it adheres to the expected structure and types.

This function can handle both simple and complex schema definitions, including nested schemas, custom validation functions, and various type constraints.

## Parameters

  - `schema` - The schema definition to be validated. It can be a map or a keyword list representing the schema.

## Returns

  - `{:ok, schema}` - If the schema is valid, returns the original schema.
  - `{:error, errors}` - If the schema is invalid, returns an error tuple with detailed error information.

## Examples

  Validating a simple schema:

  ```elixir
  schema = %{
    name: :string,
    age: :integer,
    email: {:required, :string}
  }
  assert {:ok, ^schema} = validate_schema(schema)
  ```

  Validating a nested schema:

  ```elixir
  schema = %{
    user: %{
      name: :string,
      profile: %{
        age: {:required, :integer},
        email: {:required, :string}
      }
    }
  }
  assert {:ok, ^schema} = validate_schema(schema)
  ```

  Handling invalid schema definition:

  ```elixir
  schema = %{
    name: :str,
    age: :integer,
    email: {:required, :string}
  }
  assert {:error, _errors} = validate_schema(schema)
  ```