# Kino.DataTable

A kino for interactively viewing tabular data.

## Examples

    data = [
      %{id: 1, name: "Elixir", website: "https://elixir-lang.org"},
      %{id: 2, name: "Erlang", website: "https://www.erlang.org"}
    ]

    Kino.DataTable.new(data)

The tabular view allows you to quickly preview the data
and analyze it thanks to sorting capabilities.

    data =
      for pid <- Process.list() do
        pid |> Process.info() |> Keyword.merge(registered_name: nil)
      end

    Kino.DataTable.new(
      data,
      keys: [:registered_name, :initial_call, :reductions, :stack_size]
    )

## new/2

Creates a new kino displaying given tabular data.

## Options

  * `:keys` - a list of keys to include in the table for each record.
    The order is reflected in the rendered table. Optional

  * `:name` - The displayed name of the table. Defaults to `"Data"`

  * `:sorting_enabled` - whether the table should support sorting the
    data. Sorting requires traversal of the whole enumerable, so it
    may not be desirable for large lazy enumerables. Defaults to `true`

 * `:formatter` - a 2-arity function that is used to format the data
   in the table. The first parameter passed is the `key` (column name) and
   the second is the value to be formatted. When formatting column headings
   the key is the special value `:__header__`. The formatter function must
   return either `{:ok, string}` or `:default`. When the return value is
   `:default` the default data table formatting is applied.

  * `:num_rows` - the number of rows to show in the table. Defaults to `10`.

## update/3

Updates the table to display a new tabular data.

## Options

  * `:keys` - a list of keys to include in the table for each record.
    The order is reflected in the rendered table. Optional

## Examples

    data = [
      %{id: 1, name: "Elixir", website: "https://elixir-lang.org"},
      %{id: 2, name: "Erlang", website: "https://www.erlang.org"}
    ]

    kino = Kino.DataTable.new(data)

Once created, you can update the table to display new data:

    new_data = [
      %{id: 1, name: "Elixir Lang", website: "https://elixir-lang.org"},
      %{id: 2, name: "Erlang Lang", website: "https://www.erlang.org"}
    ]

    Kino.DataTable.update(kino, new_data)