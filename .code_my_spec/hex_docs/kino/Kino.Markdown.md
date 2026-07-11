# Kino.Markdown



## new/2

Creates a new kino displaying the given Markdown content.

## Options

  * `:chunk` - whether this is a part of a larger text. Adjacent chunks
    are merged into a single text. This is useful for streaming content.
    Defaults to `false`

## Examples

### Using the `:chunk` option

Using a `Kino.Frame`.

    frame = Kino.Frame.new() |> Kino.render()

    for word <- ["who", " *let*", " `the`", " **dogs**", " out"] do
      text = Kino.Markdown.new(word, chunk: true)
      Kino.Frame.append(frame, text)
      Process.sleep(250)
    end

Without using a `Kino.Frame`.

    for word <- ["who", " *let*", " `the`", " **dogs**", " out"] do
      Kino.Markdown.new(word, chunk: true) |> Kino.render()
      Process.sleep(250)
    end

    Kino.nothing()