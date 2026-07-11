# Table

Unified access to tabular data.

Various data structures have a tabular representation, however to
access this representation, manual conversion is required. On top
of that, tabular access itself has two variants, a row-based one
and a column-based one, each useful under different circumstances.

The `Table` package provides a thin layer that unifies access to
tabular data in different formats.

## Protocol

The unified access is enabled for structs implementing the
`Table.Reader` protocol. Note that a struct may be representable
as tabular data only in some cases, so the protocol implementation
may be lax. Consequently, functions in this module will raise when
given non-tabular data.

By default the protocol is implemented for lists and maps of certain
shape.

    # List of matching key-value lists
    data = [
      [{"id", 1}, {"name", "Sherlock"}],
      [{"id", 2}, {"name", "John"}]
    ]

    # List of matching maps
    data = [
      %{"id" => 1, "name" => "Sherlock"},
      %{"id" => 2, "name" => "John"}
    ]

    # List of column tuples
    data = [
      {"id", 1..2},
      {"name", ["Sherlock", "John"]}
    ]

    # Map with column values
    data = %{
      "id" => [1, 2],
      "name" => ["Sherlock", "John"]
    }

## to_rows/2

Accesses tabular data as a sequence of rows.

Returns an enumerable that emits each row as a map.

## Options

  * `:only` - specifies a subset of columns to include in the result

## Examples

    iex> data = %{id: [1, 2, 3], name: ["Sherlock", "John", "Mycroft"]}
    iex> data |> Table.to_rows() |> Enum.to_list()
    [%{id: 1, name: "Sherlock"}, %{id: 2, name: "John"}, %{id: 3, name: "Mycroft"}]

    iex> data = [[id: 1, name: "Sherlock"], [id: 2, name: "John"], [id: 3, name: "Mycroft"]]
    iex> data |> Table.to_rows() |> Enum.to_list()
    [%{id: 1, name: "Sherlock"}, %{id: 2, name: "John"}, %{id: 3, name: "Mycroft"}]

## to_columns/2

Accesses tabular data as individual columns.

Returns a map with enumerables as values.

## Options

  * `:only` - specifies a subset of columns to include in the result

## Examples

    iex> data = [%{id: 1, name: "Sherlock"}, %{id: 2, name: "John"}, %{id: 3, name: "Mycroft"}]
    iex> columns = Table.to_columns(data)
    iex> Enum.to_list(columns.id)
    [1, 2, 3]
    iex> Enum.to_list(columns.name)
    ["Sherlock", "John", "Mycroft"]