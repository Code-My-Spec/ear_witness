# VegaLite.Data

Data is a VegaLite module designed to provide a shorthand API for charts based on data.

It relies on internal type inference, and although all options can be overridden,
only data that implements the `Table.Reader` protocol is supported.

## chart/3

Returns the specification for the a given data, a mark, and a list of
fields to be encoded.

The `mark` is either an atom, such as `:line`, or a keyword list such as
`[type: :point, line: true]`.

It encodes only the given fields from the data by default. More fields can
be added using the `:extra_fields` option. All the other fields must follow
the specifications of the `VegaLite` module.

## Options

  * `:extra_fields` - adds extra fields to the data subset for later use

## Examples

    data = [
      %{"category" => "A", "score" => 28},
      %{"category" => "B", "score" => 55}
    ]

    Data.chart(data, :bar, x: "category", y: "score")

    Data.chart(data, :bar, x: "category", extra_fields: ["score"])
    |> Vl.encode_field(:y, "score", type: :quantitative)

The above examples achieves the same results as the example below.

    Vl.new()
    |> Vl.data_from_values(data, only: ["category", "score"])
    |> Vl.mark(:bar)
    |> Vl.encode_field(:x, "category", type: :nominal)
    |> Vl.encode_field(:y, "score", type: :quantitative)

This function may also be called with an existing VegaLite spec and
without a mark:

    Vl.new()
    |> Vl.mark(:bar)
    |> Data.chart(data, x: "category", extra_fields: ["score"])

In such cases it is your responsibility to encode the mark.

## chart/4

Same as chart/3 but receives a valid `VegaLite` specification as a first argument.

## Examples

    data = [
      %{"category" => "A", "score" => 28},
      %{"category" => "B", "score" => 55}
    ]

    Vl.new(title: "With title")
    |> Data.chart(data, :bar, x: "category", y: "score")

    Vl.new(title: "With title")
    |> Vl.mark(:bar)
    |> Data.chart(data, x: "category", y: "score")

The above example achieves the same results as the example below.

    Vl.new(title: "With title")
    |> Vl.data_from_values(data, only: ["category", "score"])
    |> Vl.mark(:bar)
    |> Vl.encode_field(:x, "category", type: :nominal)
    |> Vl.encode_field(:y, "score", type: :quantitative)

## columns_for/1

Returns a map with each column and its respective inferred type for the given data.