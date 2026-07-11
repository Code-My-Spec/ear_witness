# Kino.Text



## new/2

Creates a new kino displaying the given text content.

## Options

  * `:terminal` - whether to render the text as if it were printed to
    standard output, supporting ANSI escape codes. Defaults to `false`

  * `:chunk` - whether this is a part of a larger text. Adjacent chunks
    are merged into a single text. This is useful for streaming content.
    Defaults to `false`

  * `:style` - a keyword list of CSS attributes, such as
    `style: [color: "#FF0000", font_weight: :bold]`. The currently supported
    styles are `:color`, `:font_size`, and `:font_weight`. Not supported on
    terminal outputs.

## Examples

### Using the `:chunk` option

Using a `Kino.Frame`.

    frame = Kino.Frame.new() |> Kino.render()

    for word <- ["who", " let", " the", " dogs", " out"] do
      text = Kino.Text.new(word, chunk: true)
      Kino.Frame.append(frame, text)
      Process.sleep(250)
    end

Without using a `Kino.Frame`.

    for word <- ["who", " let", " the", " dogs", " out"] do
      Kino.Text.new(word, chunk: true) |> Kino.render()
      Process.sleep(250)
    end

    Kino.nothing()