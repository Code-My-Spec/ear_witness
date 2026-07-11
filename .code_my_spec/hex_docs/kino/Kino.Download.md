# Kino.Download

A kino for downloading file content.

## Examples

    Kino.Download.new(fn ->
      "Example text"
    end)

    Kino.Download.new(
      fn -> Jason.encode!(%{"foo" => "bar"}) end,
      filename: "data.json"
    )

    Kino.Download.new(
      fn -> <<0, 1>> end,
      filename: "data.bin",
      label: "Binary data"
    )

## new/2

Creates a button for file download.

The given function is invoked to generate the file content whenever
a download is requested.

## Options

  * `:filename` - the default filename suggested for download.
    Defaults to `"download"`

  * `:label` - the button text. Defaults to the value of `:filename`
    if present and `"Download"` otherwise