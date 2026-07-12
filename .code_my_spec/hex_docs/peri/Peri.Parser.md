# Peri.Parser

The `Peri.Parser` module is responsible for managing the state during schema validation. 
It centralizes functions to handle updating data, adding errors, and managing the path within 
the data structure being validated.

## Struct
The `Peri.Parser` struct has the following fields:

- `:data` - The current state of the data being validated.
- `:errors` - A list of errors encountered during validation.
- `:path` - The current path within the data structure being validated.

## new/2

Initializes a new `Peri.Parser` struct with the given data.

## Parameters
- `data` - The initial data to be validated.

## Examples

    iex> Peri.Parser.new(%{name: "Alice"})
    %Peri.Parser{data: %{name: "Alice"}, errors: [], path: []}

## update_data/3

Updates the data in the parser state at the given key with the specified value.

## Parameters
- `state` - The current `Peri.Parser` state.
- `key` - The key to update in the data.
- `val` - The value to set at the specified key.

## Examples

    iex> state = Peri.Parser.new(%{name: "Alice"})
    iex> Peri.Parser.update_data(state, :age, 30)
    %Peri.Parser{data: %{name: "Alice", age: 30}, errors: [], path: []}

## add_error/2

Adds an error to the parser state's list of errors.

## Parameters
- `state` - The current `Peri.Parser` state.
- `err` - The `%Peri.Error{}` struct representing the error to add.

## Examples

    iex> state = Peri.Parser.new(%{name: "Alice"})
    iex> error = %Peri.Error{path: [:name], message: "is required", content: []}
    iex> Peri.Parser.add_error(state, error)
    %Peri.Parser{data: %{name: "Alice"}, errors: [%Peri.Error{path: [:name], message: "is required", content: []}], path: []}

## for_list_element/3

Creates a new parser for a list element, preserving the root data.

## Parameters
- `element_data` - The data for the current list element.
- `parent_parser` - The parent parser containing root data and path information.
- `index` - The index of the element in the list.

## Examples

    iex> parent = Peri.Parser.new(%{items: [1, 2, 3]}, root_data: %{items: [1, 2, 3]})
    iex> Peri.Parser.for_list_element(1, parent, 0)
    %Peri.Parser{data: 1, current_data: 1, root_data: %{items: [1, 2, 3]}, errors: [], path: [0]}

## bump_ref_depth/1

Increments the ref-resolution depth counter. Used by `{:ref, _}`
directive resolution to bound recursion on cyclic data.