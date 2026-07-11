# Kino.VegaLite

A kino wrapping [VegaLite](https://hexdocs.pm/vega_lite) graphic.

This kino allow for rendering regular VegaLite graphic and then
streaming new data points to update the graphic.

## Examples

    chart =
      Vl.new(width: 400, height: 400)
      |> Vl.mark(:line)
      |> Vl.encode_field(:x, "x", type: :quantitative)
      |> Vl.encode_field(:y, "y", type: :quantitative)
      |> Kino.VegaLite.render()

    for i <- 1..300 do
      point = %{x: i / 10, y: :math.sin(i / 10)}
      Kino.VegaLite.push(chart, point)
      Process.sleep(25)
    end

## new/1

Creates a new kino with the given VegaLite definition.

## configure/1

Applies global configuration options for the VegaLite kinos.

## Options

  * `:theme` - the theme to be applied on the rendered VegaLite
    charts. Currently the only supported theme is `:livebook`. If
    set to `nil`, no theme is applied. Defaults to `:livebook`.

## render/1

Renders and returns a new kino with the given VegaLite definition.

It is equivalent to:

    vega_lite |> Kino.VegaLite.new() |> Kino.render()

## push/3

Appends a single data point to the graphic dataset.

## Options

  * `:window` - the maximum number of data points to keep.
    This option is useful when you are appending new
    data points to the plot over a long period of time

  * `dataset` - name of the targeted dataset from
    the VegaLite specification. Defaults to the default
    anonymous dataset

## push_many/3

Appends a number of data points to the graphic dataset.

See `push/3` for more details.

## set_param/3

Updates a vega-lite [parameter's](https://vega.github.io/vega-lite/docs/parameter.html#variable-parameters) value.

The parameter must be registered: `VegaLite.param(vl, "param_name", opts)`.

To use the parameter in the chart, set a property to `[expr: "param_name"]`.

## Examples

    chart =
      VegaLite.new(width: 400, height: 400)
      |> VegaLite.param("stroke_width", value: 3)
      |> VegaLite.mark(:line, stroke_width: [expr: "stroke_width"])
      |> VegaLite.encode_field(:x, "x", type: :quantitative)
      |> VegaLite.encode_field(:y, "y", type: :quantitative)
      |> Kino.VegaLite.new()
      |> Kino.render()

    Kino.VegaLite.set_param(chart, "stroke_width", 10)

## clear/2

Removes all data points from the graphic dataset.

## Options

  * `dataset` - name of the targeted dataset from
    the VegaLite specification. Defaults to the default
    anonymous dataset

## periodically/4

Registers a callback to run periodically in the kino process.

The callback is run every `interval_ms` milliseconds and receives
the accumulated value. The callback should return either of:

  * `{:cont, acc}` - the continue with the new accumulated value

  * `:halt` - to no longer schedule callback evaluation

The callback is run for the first time immediately upon registration.