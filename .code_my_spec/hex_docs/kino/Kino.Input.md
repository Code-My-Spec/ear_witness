# Kino.Input

Various input elements for entering data.

## Examples

First, create an input and make sure it is rendered,
either by placing it at the end of a code cell or by
explicitly rendering it with `Kino.render/1`.

    input = Kino.Input.text("Name")

Then read the value after the input has been rendered:

    name = Kino.Input.read(input)

All inputs are shared by default: once you change the input,
your changes will be immediately replicated to all users
reading the notebook. Use `Kino.Control.form/2` if you want
each user to have their own input.

## Async API

You can subscribe to input changes or use the `Stream`
API for event feed. See the `Kino.Control` module for
more details.

## text/2

Creates a new text input.

## Options

  * `:default` - the initial input value. Defaults to `""`

  * `:debounce` - determines when input changes are emitted. When
    set to `:blur`, the change propagates when the user leaves the
    input. When set to a non-negative number of milliseconds, the
    change propagates after the specified delay. Defaults to `:blur`

## textarea/2

Creates a new multiline text input.

## Options

  * `:default` - the initial input value. Defaults to `""`

  * `:monospace` - whether to use a monospace font inside the textarea.
    Defaults to `false`

  * `:debounce` - determines when input changes are emitted. When
    set to `:blur`, the change propagates when the user leaves the
    input. When set to a non-negative number of milliseconds, the
    change propagates after the specified delay. Defaults to `:blur`

## password/2

Creates a new password input.

This is similar to text input, except the content is not
visible by default.

## Options

  * `:default` - the initial input value. Defaults to `""`

  * `:debounce` - determines when input changes are emitted. When
    set to `:blur`, the change propagates when the user leaves the
    input. When set to a non-negative number of milliseconds, the
    change propagates after the specified delay. Defaults to `:blur`

## number/2

Creates a new number input.

The input value can be either a number or `nil`.

## Options

  * `:default` - the initial input value. Defaults to `nil`

  * `:min` - the minimum value

  * `:max` - the maximum value

  * `:step` - the input increment

  * `:debounce` - determines when input changes are emitted. When
    set to `:blur`, the change propagates when the user leaves the
    input. When set to a non-negative number of milliseconds, the
    change propagates after the specified delay. Defaults to `:blur`

## url/2

Creates a new URL input.

The input value can be either a valid URL string or `nil`.

## Options

  * `:default` - the initial input value. Defaults to `nil`

  * `:debounce` - determines when input changes are emitted. When
    set to `:blur`, the change propagates when the user leaves the
    input. When set to a non-negative number of milliseconds, the
    change propagates after the specified delay. Defaults to `:blur`

## select/3

Creates a new select input.

The input expects a list of options in the form `[{value, label}]`,
where `value` is an arbitrary term and `label` is a descriptive
string.

## Options

  * `:default` - the initial input value. Defaults to the first
    value from the given list of options

## Examples

    Kino.Input.select("Language", [en: "English", fr: "Français"])

    Kino.Input.select("Language", [{1, "One"}, {2, "Two"}, {3, "Three"}])

## checkbox/2

Creates a new checkbox.

The input value can be either `true` or `false`.

## Options

  * `:default` - the initial input value. Defaults to `false`

## range/2

Creates a new slider input.

The input value can be either float in the configured range.

## Options

  * `:default` - the initial input value. Defaults to the
    minimum value

  * `:min` - the minimum value

  * `:max` - the maximum value

  * `:step` - the slider increment

  * `:debounce` - determines when input changes are emitted. When
    set to a non-negative number of milliseconds, the change propagates
    after the specified delay. Defaults to `250`

## utc_datetime/2

Creates a new datetime input.

The input is editable in user-local time zone, however the value
is always read in UTC as a `%NaiveDateTime{}` struct.

## Options

  * `:default` - the initial input value. Defaults to `nil`

  * `:min` - the minimum datetime value (in UTC)

  * `:max` - the maximum datetime value (in UTC)

## utc_time/2

Creates a new time input.

The input is editable in user-local time zone, however the value
is always read in UTC as a `%Time{}` struct.

## Options

  * `:default` - the initial input value. Defaults to `nil`

  * `:min` - the minimum time value (in UTC)

  * `:max` - the maximum time value (in UTC)

## date/2

Creates a new date input.

The input is read as a `%Date{}` struct.

## Options

  * `:default` - the initial input value. Defaults to `nil`

  * `:min` - the minimum date value

  * `:max` - the maximum date value

## color/2

Creates a new color input.

The input value can be a hex color string.

## Options

  * `:default` - the initial input value. Defaults to `#6583FF`

  * `:debounce` - determines when input changes are emitted. When
    set to `:blur`, the change propagates when the user leaves the
    input. When set to a non-negative number of milliseconds, the
    change propagates after the specified delay. Defaults to `:blur`

## image/2

Creates a new image input.

The input value is a map, with an image file and metadata:

    %{
      file_ref: term(),
      height: pos_integer(),
      width: pos_integer(),
      format: :rgb | :png | :jpeg
    }

Note that the value can also be `nil`, if no image is selected.

The file path can then be accessed using `file_path/1`.

> #### Warning {: .warning}
>
> The image input is shared by default: once you upload an image,
> the image will be replicated to all users reading the notebook.
> Use `Kino.Control.form/2` if you want each user to have a distinct
> image upload with an explicit submission button.

## Options

  * `:format` - the format to read the image as, either of:

    * `:rgb` (default) - the binary includes raw pixel values, each
      encoded as a single byte in the HWC order. Such binary can be
      directly converted to an `Nx` tensor, with no additional decoding

    * `:png`

    * `:jpeg` (or `:jpg`)

  * `:size` - the size to fit the image into, given as `{height, width}`

  * `:fit` - the strategy of fitting the image into `:size`, either of:

    * `:contain` (default) - resizes the image, such that it fits in
      a box of `:size`, but preserving the aspect ratio. The resulting
      image can be smaller or equal to `:size`

    * `:match` - resizes the image to `:size`, with no respect for
      aspect ratio

    * `:pad` - same as `:contain`, but pads the image to match `:size`
      exactly

    * `:crop` - resizes the image, such that one edge fits in `:size`
      and the other overflows, then center-crops the image to match
      `:size` exactly

## audio/2

Creates a new audio input.

The input value is a map, with an audio file and metadata:

    %{
      file_ref: term(),
      num_channels: pos_integer(),
      sampling_rate: pos_integer(),
      format: :pcm_f32 | :wav
    }

Note that the value can also be `nil`, if no audio is selected.

The file path can then be accessed using `file_path/1`.

> #### Warning {: .warning}
>
> The audio input is shared by default: once you upload an audio,
> the audio will be replicated to all users reading the notebook.
> Use `Kino.Control.form/2` if you want each user to have a distinct
> audio upload with an explicit submission button.

## Options

  * `:format` - the format to read the audio as, either of:

    * `:pcm_f32` (default) - the PCM (32-bit float) format. Note that
      the binary uses native system endianness. Such binary can be
      directly converted to an `Nx` tensor, with no additional decoding

    * `:wav`

  * `:sampling_rate` - the sampling rate (samples per second) of
    the audio data. Defaults to `48_000`

## file/2

Creates a new file input.

The input value is a map, with a file and metadata:

    %{
      file_ref: term(),
      client_name: String.t()
    }

Note that the value can also be `nil`, if no file is selected.

The file path can then be accessed using `file_path/1`.

> #### Warning {: .warning}
>
> The file input is shared by default: once you upload a file,
> the file will be replicated to all users reading the notebook.
> Use `Kino.Control.form/2` if you want each user to have a distinct
> file upload with an explicit submission button.

## Considerations

Note that a file may be deleted in certain cases, specifically:

  * when the file is reuploaded
  * when used with a form and the uploading user leaves
  * when the input is removed

The deletion is not immediate and you are unlikely to run into this
in practice, however theoretically `file_path/1` may point to a
non-existing file.

## Options

  * `:accept` - the list of accepted file types (either extensions
    or MIME types) or `:any`. Defaults to `:any`

## Examples

To read the content of currently uploaded file we would do:

    # [Cell 1]

    input = Kino.Input.file("File")

    # [Cell 2]

    value = Kino.Input.read(input)
    path = Kino.Input.file_path(value.file_ref)
    File.read!(path)

And here's how we could process an asynchronous form submission:

    # [Cell 1]

    form = Kino.Control.form([file: Kino.Input.file("File")], submit: "Send")

    # [Cell 2]

    form
    |> Kino.Control.stream()
    |> Kino.listen(fn event ->
      path = Kino.Input.file_path(event.data.file.file_ref)
      content = File.read!(path)
      IO.inspect(content)
    end)

## read/1

Synchronously reads the current input value.

## Examples

    input =
      Kino.Input.text("Name")
      |> Kino.render()

    Kino.Input.read(input)

## file_path/1

Returns file path for the given file identifier.