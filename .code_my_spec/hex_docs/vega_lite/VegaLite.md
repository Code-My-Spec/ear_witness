# VegaLite

Elixir bindings to [Vega-Lite](https://vega.github.io/vega-lite).

Vega-Lite offers a high-level grammar for composing interactive graphics,
where every graphic is specified in a declarative fashion relying solely
on JSON syntax. To learn more about Vega-Lite please refer to
the [documentation](https://vega.github.io/vega-lite/docs)
and explore numerous [examples](https://vega.github.io/vega-lite/examples).

This package offers a tiny layer of functionality that makes it easier
to build a Vega-Lite graphics specification.

## Composing graphics

We offers a light-weight pipeline API akin to the JSON specification.
Translating existing Vega-Lite specifications to such specification
should be very intuitive in most cases.

Composing a basic Vega-Lite graphic usually consists of the following steps:

    alias VegaLite, as: Vl

    # Initialize the specification, optionally with some top-level properties
    Vl.new(width: 400, height: 400)

    # Specify data source for the graphic, see the data_from_* functions
    |> Vl.data_from_values(iteration: 1..100, score: 1..100)
    # |> Vl.data_from_values([%{iteration: 1, score: 1}, ...])
    # |> Vl.data_from_url("...")

    # Pick a visual mark for the graphic
    |> Vl.mark(:line)
    # |> Vl.mark(:point, tooltip: true)

    # Map data fields to visual properties of the mark, like position or shape
    |> Vl.encode_field(:x, "iteration", type: :quantitative)
    |> Vl.encode_field(:y, "score", type: :quantitative)
    # |> Vl.encode_field(:color, "country", type: :nominal)
    # |> Vl.encode_field(:size, "count", type: :quantitative)

Then, you can compose multiple graphics using `layers/2`, `concat/3`,
`repeat/3` or `facet/3`.

    Vl.new()
    |> Vl.data_from_url("https://vega.github.io/editor/data/weather.csv")
    |> Vl.transform(filter: "datum.location == 'Seattle'")
    |> Vl.concat([
      Vl.new()
      |> Vl.mark(:bar)
      |> Vl.encode_field(:x, "date", time_unit: :month, type: :ordinal)
      |> Vl.encode_field(:y, "precipitation", aggregate: :mean),
      Vl.new()
      |> Vl.mark(:point)
      |> Vl.encode_field(:x, "temp_min", bin: true)
      |> Vl.encode_field(:y, "temp_max", bin: true)
      |> Vl.encode(:size, aggregate: :count)
    ])

Additionally, you can use `transform/2` to preprocess the data,
`param/3` for introducing interactivity and `config/2` for
global customization.

> #### Option casing {: .info}
>
> Note that the specification uses snake-case instead of camel-case.
> See [Options](#module-options).

### Using JSON specification

Alternatively you can parse a Vega-Lite JSON specification directly.
This approach makes it easy to explore numerous examples available online.

    alias VegaLite, as: Vl

    Vl.from_json("""
    {
      "data": { "url": "https://vega.github.io/editor/data/cars.json" },
      "mark": "point",
      "encoding": {
        "x": { "field": "Horsepower", "type": "quantitative" },
        "y": { "field": "Miles_per_Gallon", "type": "quantitative" }
      }
    }
    """)

The result of `VegaLite.from_json/1` function can then be passed
through any other function to further customize the specification.
In particular, it may be useful to parse a JSON specification
and add your custom data with `VegaLite.data_from_values/3`.

## Options

Most `VegaLite` functions accept an optional list of options,
which are converted directly as the specification properties.
To provide a more Elixir-friendly experience, the options
are automatically normalized, so you can use keyword lists
and snake-case atom keys. For example, if you specify
`axis: [label_angle: -45]`, this library will automatically
rewrite it `labelAngle`, which is the name used by the VegaLite
specification.

## Export

`VegaLite` graphics can be exported into various formats, such as
SVG, PNG and PDF thorugh the [`:vega_lite_convert`](https://hexdocs.pm/vega_lite_convert)
package.

## new/1

Returns a new specification wrapped in the `VegaLite` struct.

All provided options are converted to top-level properties
of the specification.

## Examples

    Vl.new(
      title: "My graph",
      width: 200,
      height: 200
    )
    |> ...


See [the docs](https://vega.github.io/vega-lite/docs/spec.html) for more details.

## from_json/1

Parses the given Vega-Lite JSON specification
and wraps in the `VegaLite` struct for further processing.

## Examples

    Vl.from_json("""
    {
      "data": { "url": "https://vega.github.io/editor/data/cars.json" },
      "mark": "point",
      "encoding": {
        "x": { "field": "Horsepower", "type": "quantitative" },
        "y": { "field": "Miles_per_Gallon", "type": "quantitative" }
      }
    }
    """)


See [the docs](https://vega.github.io/vega-lite/docs/spec.html) for more details.

## from_spec/1

Wraps the given Vega-Lite specification in the `VegaLite`
struct for further processing.

There is also `from_json/1` that handles JSON parsing for you.

See [the docs](https://vega.github.io/vega-lite/docs/spec.html) for more details.

## to_spec/1

Returns the underlying Vega-Lite specification.

The result is a nested Elixir datastructure that serializes
to Vega-Lite JSON specification.

See [the docs](https://vega.github.io/vega-lite/docs/spec.html) for more details.

## data/2

Sets data properties in the specification.

Defining the data source is usually the first step
when building a graphic. For most use cases it's preferable
to use more specific functions like `data_from_url/3` or `data_from_values/3`.

All provided options are converted to data properties.

## Examples

    Vl.new()
    |> Vl.data(sequence: [start: 0, stop: 12.7, step: 0.1, as: "x"])
    |> ...


See [the docs](https://vega.github.io/vega-lite/docs/data.html) for more details.

## data_from_url/3

Sets data URL in the specification.

The URL should be accessible by whichever client renders
the specification, so preferably an absolute one.

All provided options are converted to data properties.

## Examples

    Vl.new()
    |> Vl.data_from_url("https://vega.github.io/editor/data/penguins.json")
    |> ...

    Vl.new()
    |> Vl.data_from_url("https://vega.github.io/editor/data/stocks.csv", format: :csv)
    |> ...


See [the docs](https://vega.github.io/vega-lite/docs/data.html#url) for more details.

## data_from_values/3

Sets inline data in the specification.

Any tabular data is accepted, as long as it adheres to the
`Table.Reader` protocol.

## Options

  * `:only` - specifies a subset of fields to pick from the data

All other options are converted to data properties.

## Examples

    data = [
      %{"category" => "A", "score" => 28},
      %{"category" => "B", "score" => 55}
    ]

    Vl.new()
    |> Vl.data_from_values(data)
    |> ...

Note that any tabular data is accepted, as long as it adheres
to the `Table.Reader` protocol. For example that's how we can
pass individual series:

    xs = 1..100
    ys = 1..100

    Vl.new()
    |> Vl.data_from_values(x: xs, y: ys)
    |> ...

See [the docs](https://vega.github.io/vega-lite/docs/data.html#inline) for more details.

## datasets_from_values/2

Specifies top-level datasets.

Datasets can be used as a data source further in the specification.
This is useful if you need to refer to the data in multiple places
or use a `transform/2` like `:lookup`.

Datasets should be a key-value enumerable, where key is the dataset
name and value is tabular data as in `data_from_values/3`.

## Examples

    results = [
      %{"category" => "A", "score" => 28},
      %{"category" => "B", "score" => 55}
    ]

    points = [
      %{"x" => "1", "y" => 10},
      %{"x" => "2", "y" => 100}
    ]

    Vl.new()
    |> Vl.datasets_from_values(results: results, points: points)
    # Use one of the data sets as the primary data
    |> Vl.data(name: "results")
    |> ...


See [the docs](https://vega.github.io/vega-lite/docs/data.html#datasets) for more details.

## encode/3

Adds an encoding entry to the specification.

Visual channel represents a property of a visual mark,
for instance the `:x` and `:y` channels specify where
a point should be placed.
Encoding defines the source of values for those channels.

In most cases you want to map specific data field
to visual channels, prefer the `encode_field/4` function for that.

All provided options are converted to channel properties.

## Examples

    Vl.new()
    |> Vl.encode(:x, value: 2)
    |> ...

    Vl.new()
    |> Vl.encode(:y, aggregate: :count, type: :quantitative)
    |> ...

    Vl.new()
    |> Vl.encode(:y, field: "price")
    |> ...

Alternatively, a list of property lists may be given:

    Vl.new()
    |> Vl.encode(:tooltip, [
      [field: "height", type: :quantitative],
      [field: "width", type: :quantitative]
    ])
    |> ...

See [the docs](https://vega.github.io/vega-lite/docs/encoding.html) for more details.

## encode_field/4

Adds field encoding entry to the specification.

A shorthand for `encode/3`, mapping a data field to a visual channel.

For example, if the data has `"price"` and `"time"` fields,
you could map `"time"` to the `:x` channel and `"price"`
to the `:y` channel. This, combined with a line mark,
would then result in price-over-time plot.

All provided options are converted to channel properties.

## Types

Field data type is automatically inferred, but oftentimes
needs to be specified explicitly to get the desired result.
The `:type` option can be either of:

  * `:quantitative` - when the field expresses some kind of quantity, typically numerical

  * `:temporal` - when the field represents a point in time

  * `:nominal` - when the field represents a category

  * `:ordinal` - when the field represents a ranked order.
    It is similar to `:nominal`, but there is a clear order of values

  * `:geojson` - when the field represents a geographic shape
    adhering to the [GeoJSON](https://geojson.org) specification

See [the docs](https://vega.github.io/vega-lite/docs/type.html) for more details on types.

## Examples

    Vl.new()
    |> Vl.data_from_values(...)
    |> Vl.mark(:point)
    |> Vl.encode_field(:x, "time", type: :temporal)
    |> Vl.encode_field(:y, "price", type: :quantitative)
    |> Vl.encode_field(:color, "country", type: :nominal)
    |> Vl.encode_field(:size, "count", type: :quantitative)
    |> ...

    Vl.new()
    |> Vl.encode_field(:x, "date", time_unit: :month, title: "Month")
    |> Vl.encode_field(:y, "price", type: :quantitative, aggregate: :mean, title: "Mean product price")
    |> ...


See [the docs](https://vega.github.io/vega-lite/docs/encoding.html#field-def) for more details.

## encode_repeat/4

Adds repeated field encoding entry to the specification.

A shorthand for `encode/3`, mapping a field to a visual channel,
as given by the repeat operator.

Repeat type must be either `:repeat`, `:row`, `:column` or `:layer`
and correspond to the repeat definition.

All provided options are converted to channel properties.

## Examples

See `repeat/3` to see the full picture.

See [the docs](https://vega.github.io/vega-lite/docs/repeat.html) for more details.

## mark/3

Sets mark type in the specification.

Mark is a predefined visual object like a point or a line.
Visual properties of the mark are defined by encoding.

All provided options are converted to mark properties.

## Examples

    Vl.new()
    |> Vl.mark(:point)
    |> ...

    Vl.new()
    |> Vl.mark(:point, tooltip: true)
    |> ...


See [the docs](https://vega.github.io/vega-lite/docs/mark.html) for more details.

## transform/2

Adds a transformation to the specification.

Transformation describes an operation on data,
like calculating new fields, aggregating or filtering.

All provided options are converted to transform properties.

## Examples

    Vl.new()
    |> Vl.data_from_values(...)
    |> Vl.transform(calculate: "sin(datum.x)", as: "sin_x")
    |> ...

    Vl.new()
    |> Vl.data_from_values(...)
    |> Vl.transform(filter: "datum.height > 150")
    |> ...

    Vl.new()
    |> Vl.data_from_values(...)
    |> Vl.transform(regression: "price", on: "date")
    |> ...


See [the docs](https://vega.github.io/vega-lite/docs/transform.html) for more details.

## param/3

Adds a parameter to the specification.

Parameters are the basic building blocks for introducing
interactions to graphics.

All provided options are converted to parameter properties.

## Examples

    Vl.new()
    |> Vl.data_from_values(...)
    |> Vl.concat([
      Vl.new()
      # Define a parameter named "brush", whose value is a user-selected interval on the x axis
      |> Vl.param("brush", select: [type: :interval, encodings: [:x]])
      |> Vl.mark(:area)
      |> Vl.encode_field(:x, "date", type: :temporal)
      |> ...,
      Vl.new()
      |> Vl.mark(:area)
      # Use the "brush" parameter value to limit the domain of this view
      |> Vl.encode_field(:x, "date", type: :temporal, scale: [domain: [param: "brush"]])
      |> ...
    ])

  Parameters can also be specified using UI inputs, or computed based
  on other parameters:

    Vl.new()
    |> Vl.param("height", value: 20, bind: [input: :range, min: 1, max: 100, step: 1])
    |> Vl.param("halfHeight", expr: "height / 2")
    |> ...

See [the docs](https://vega.github.io/vega-lite/docs/parameter.html) for more details.

## config/2

Adds view configuration to the specification.

Configuration allows for setting general properties of the visualization.

All provided options are converted to configuration properties
and merged with the existing configuration in a shallow manner.

## Examples

    Vl.new()
    |> ...
    |> Vl.config(
      view: [stroke: :transparent],
      padding: 100,
      background: "#333333"
    )


See [the docs](https://vega.github.io/vega-lite/docs/config.html) for more details.

## projection/2

Adds a projection spec to the specification.

Projection maps longitude and latitude pairs to x, y coordinates.

## Examples

    Vl.new()
    |> Vl.data_from_values(...)
    |> Vl.projection(type: :albers_usa)
    |> Vl.mark(:circle)
    |> Vl.encode_field(:longitude, "longitude", type: :quantitative)
    |> Vl.encode_field(:latitude, "latitude", type: :quantitative)


See [the docs](https://vega.github.io/vega-lite/docs/projection.html) for more details.

## layers/2

Builds a layered multi-view specification from the given
list of single view specifications.

## Examples

    Vl.new()
    |> Vl.data_from_values(...)
    |> Vl.layers([
      Vl.new()
      |> Vl.mark(:line)
      |> Vl.encode_field(:x, ...)
      |> Vl.encode_field(:y, ...),
      Vl.new()
      |> Vl.mark(:rule)
      |> Vl.encode_field(:y, ...)
      |> Vl.encode(:size, value: 2)
    ])

    Vl.new()
    |> Vl.data_from_values(...)
    # Note: top-level data, encoding, transforms are inherited
    # by the child views unless overridden
    |> Vl.encode_field(:x, ...)
    |> Vl.layers([
      ...
    ])


See [the docs](https://vega.github.io/vega-lite/docs/layer.html) for more details.

## concat/3

Builds a concatenated multi-view specification from
the given list of single view specifications.

The concat type must be either `:wrappable` (default), `:horizontal` or `:vertical`.

## Examples

    Vl.new()
    |> Vl.data_from_values(...)
    |> Vl.concat([
      Vl.new()
      |> ...,
      Vl.new()
      |> ...,
      Vl.new()
      |> ...
    ])

    Vl.new()
    |> Vl.data_from_values(...)
    |> Vl.concat(
      [
        Vl.new()
        |> ...,
        Vl.new()
        |> ...
      ],
      :horizontal
    )


See [the docs](https://vega.github.io/vega-lite/docs/concat.html) for more details.

## facet/3

Builds a facet multi-view specification from the given
single-view template.

Facet definition must be either a [field definition](https://vega.github.io/vega-lite/docs/facet.html#field-def)
or a [row/column mapping](https://vega.github.io/vega-lite/docs/facet.html#mapping).

Note that you can also create facet graphics by using
the `:facet`, `:column` and `:row` encoding channels.

## Examples

    Vl.new()
    |> Vl.data_from_values(...)
    |> Vl.facet(
      [field: "country"],
      Vl.new()
      |> Vl.mark(:bar)
      |> Vl.encode_field(:x, ...)
      |> Vl.encode_field(:y, ...)
    )

    Vl.new()
    |> Vl.data_from_values(...)
    |> Vl.facet(
      [
        row: [field: "country", title: "Country"],
        column: [field: "year", title: "Year"]
      ]
      Vl.new()
      |> Vl.mark(:bar)
      |> Vl.encode_field(:x, ...)
      |> Vl.encode_field(:y, ...)
    )


See [the docs](https://vega.github.io/vega-lite/docs/facet.html#facet-operator) for more details.

## repeat/3

Builds a repeated multi-view specification from the given
single-view template.

Repeat definition must be either a list of fields
or a [row/column/layer mapping](https://vega.github.io/vega-lite/docs/repeat.html#repeat-mapping).
Then some channels can be bound to a repeated field using `encode_repeat/4`.

## Examples

    # Simple repeat
    Vl.new()
    |> Vl.data_from_values(...)
    |> Vl.repeat(
      ["temp_max", "precipitation", "wind"],
      Vl.new()
      |> Vl.mark(:line)
      |> Vl.encode_field(:x, "date", time_unit: :month)
      # The graphic will be reapeated with :y mapped to "temp_max",
      # "precipitation" and "wind" respectively
      |> Vl.encode_repeat(:y, :repeat, aggregate: :mean)
    )

    # Grid repeat
    Vl.new()
    |> Vl.data_from_values(...)
    |> Vl.repeat(
      [
        row: [
          "beak_length",
          "beak_depth",
          "flipper_length",
          "body_mass"
        ],
        column: [
          "body_mass",
          "flipper_length",
          "beak_depth",
          "beak_length"
        ]
      ],
      Vl.new()
      |> Vl.mark(:point)
      # The graphic will be repeated for every combination of :x and :y
      # taken from the :row and :column lists above
      |> Vl.encode_repeat(:x, :column, type: :quantitative)
      |> Vl.encode_repeat(:y, :row, type: :quantitative)
    )


See [the docs](https://vega.github.io/vega-lite/docs/repeat.html) for more details.

## resolve/3

Adds a resolve entry to the specification.

Resolution defines how multi-view graphics are combined
with regard to scales, axis and legend.

## Example

    Vl.new()
    |> Vl.data_from_values(...)
    |> Vl.layers([
      Vl.new()
      |> ...,
      Vl.new()
      |> ...
    ])
    |> Vl.resolve(:scale, y: :independent)


See [the docs](https://vega.github.io/vega-lite/docs/resolve.html) for more details.