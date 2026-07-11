# Kino.Layout

Layout utilities for arranging multiple kinos together.

## tabs/1

Arranges outputs into separate tabs.

## Examples

    data = [
      %{id: 1, name: "Elixir", website: "https://elixir-lang.org"},
      %{id: 2, name: "Erlang", website: "https://www.erlang.org"}
    ]

    Kino.Layout.tabs([
      Table: Kino.DataTable.new(data),
      Raw: data
    ])

## grid/2

Arranges outputs into a grid.

Note that the grid does not support scrolling, it always squeezes
the content, such that it does not exceed the page width.

## Options

  * `:columns` - the number of columns in the grid. Optionally, supports
    a tuple of column width ratio, such as `{1, 2, 1}`, for three columns,
    where the middle one is twice as wide as the others. Defaults to `1`

  * `:boxed` - whether the grid should be wrapped in a bordered box.
    Defaults to `false`

  * `:gap` - the amount of spacing between grid items in pixels.
    Defaults to `8`

  * `:max_height` - the maximum height of the grid in pixels. When
    enabled, a scroll appears if the grid content exceeds the given
    height

## Examples

    images =
      for path <- paths do
        path |> File.read!() |> Kino.Image.new(:jpeg)
      end

    Kino.Layout.grid(images, columns: 3)