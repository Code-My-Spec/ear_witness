# Kino.Shorts

Shortcuts for building Kinos.

This module provides an easy to use Kino API and is meant to
be imported into your notebooks:

    import Kino.Shorts

## data_table/2

Renders a data table output for user-provided tabular data.

The data must implement the `Table.Reader` protocol. This
function is a wrapper around `Kino.DataTable.new/1`.

## Examples

    import Kino.Shorts

    data = [
      %{id: 1, name: "Elixir", website: "https://elixir-lang.org"},
      %{id: 2, name: "Erlang", website: "https://www.erlang.org"}
    ]

    data_table(data)

## image/2

Renders an image of any given format.

It is a wrapper around `Kino.Image.new/2`.

## Examples

    import Kino.Shorts
    content = File.read!("/path/to/image.jpeg")
    image(content, "image/jpeg")

## audio/2

Renders an audio of any given format.

It is a wrapper around `Kino.Audio.new/2`.

## Examples

    import Kino.Shorts
    content = File.read!("/path/to/audio.wav")
    audio(content, :wav)

## video/2

Renders a video of any given format.

It is a wrapper around `Kino.Video.new/2`.

## Examples

    import Kino.Shorts
    content = File.read!("/path/to/video.mp4")
    video(content, :mp4)

## download/2

Renders a file download button.

The given function is invoked to generate the file content whenever
a download is requested.

It is a wrapper around `Kino.Download.new/2`.

## Options

  * `:filename` - the default filename suggested for download.
    Defaults to `"download"`

  * `:label` - the button text. Defaults to the value of `:filename`
    if present and `"Download"` otherwise

## Examples

    download(fn ->
      "Example text"
    end)

    download(
      fn -> Jason.encode!(%{"foo" => "bar"}) end,
      filename: "data.json"
    )

    download(
      fn -> <<0, 1>> end,
      filename: "data.bin",
      label: "Binary data"
    )

## text/1

Renders plain text content.

It is similar to `markdown/1`, however doesn't interpret any markup.

It is a wrapper around `Kino.Text.new/1`.

## Examples

    import Kino.Shorts
    text("Hello!")

## frame/1

A placeholder for static outputs that can be dynamically updated.

The frame can be updated with the `Kino.Frame` module API.
Also see `Kino.animate/3`.

## Examples

    import Kino.Shorts
    frame = frame() |> Kino.render()

    for i <- 1..100 do
      Kino.Frame.render(frame, i)
      Process.sleep(50)
    end

## tree/1

Displays arbitrarily nested data structure as a tree view.

It is a wrapper around `Kino.Tree.new/1`.

## Examples

    import Kino.Shorts
    tree(Process.info(self()))

## read_text/2

Renders and reads a new text input.

## Options

  * `:default` - the initial input value. Defaults to `""`

## read_textarea/2

Renders and reads a new multiline text input.

## Options

  * `:default` - the initial input value. Defaults to `""`

  * `:monospace` - whether to use a monospace font inside the textarea.
    Defaults to `false`

## read_password/2

Renders and reads a new password input.

## Options

  * `:default` - the initial input value. Defaults to `""`

## read_number/2

Renders and reads a new number input.

## Options

  * `:default` - the initial input value. Defaults to `nil`

## read_url/2

Renders and reads a new URL input.

## Options

  * `:default` - the initial input value. Defaults to `nil`

## read_select/3

Renders and reads a new select input.

The input expects a list of options in the form `[{value, label}]`,
where `value` is an arbitrary term and `label` is a descriptive
string.

## Options

  * `:default` - the initial input value. Defaults to the first
    value from the given list of options

## Examples

    read_select("Language", [en: "English", fr: "Français"])

    read_select("Language", [{1, "One"}, {2, "Two"}, {3, "Three"}])

## read_checkbox/2

Renders and reads a new checkbox.

## Options

  * `:default` - the initial input value. Defaults to `false`

## read_range/2

Renders and reads a new slider input.

## Options

  * `:default` - the initial input value. Defaults to the
    minimum value

  * `:min` - the minimum value

  * `:max` - the maximum value

  * `:step` - the slider increment

## read_utc_datetime/2

Renders and reads a new datetime input.

## Options

  * `:default` - the initial input value. Defaults to `nil`

  * `:min` - the minimum datetime value (in UTC)

  * `:max` - the maximum datetime value (in UTC)

## read_utc_time/2

Renders and reads a new time input.

## Options

  * `:default` - the initial input value. Defaults to `nil`

  * `:min` - the minimum time value (in UTC)

  * `:max` - the maximum time value (in UTC)

## read_date/2

Renders and reads a new date input.

## Options

  * `:default` - the initial input value. Defaults to `nil`

  * `:min` - the minimum date value

  * `:max` - the maximum date value

## read_color/2

Renders and reads a new color input.

## Options

  * `:default` - the initial input value. Defaults to `#6583FF`

## read_image/2

Renders and reads a new image input.

See `Kino.Input.image/2` for all supported formats and options.

> #### Warning {: .warning}
>
> The image input is shared by default: once you upload an image,
> the image will be replicated to all users reading the notebook.
> Use `Kino.Control.form/2` if you want each user to have a distinct
> image upload with an explicit submission button.

## read_audio/2

Renders and reads a new audio input.

See `Kino.Input.audio/2` for all supported formats and options.

> #### Warning {: .warning}
>
> The audio input is shared by default: once you upload an audio,
> the audio will be replicated to all users reading the notebook.
> Use `Kino.Control.form/2` if you want each user to have a distinct
> audio upload with an explicit submission button.

## read_file/2

Renders and reads a new file input.

The file path can then be accessed using `Kino.Input.file_path/1`.
See `Kino.Input.file/2` for additional considerations.

> #### Warning {: .warning}
>
> The file input is shared by default: once you upload a file,
> the file will be replicated to all users reading the notebook.
> Use `Kino.Control.form/2` if you want each user to have a distinct
> file upload with an explicit submission button.

## Options

  * `:accept` - the list of accepted file types (either extensions
    or MIME types) or `:any`. Defaults to `:any`