# Kino.Frame

A placeholder for outputs.

A frame wraps outputs that can be dynamically updated at
any time.

Also see `Kino.animate/3` which offers a convenience on
top of this kino.

## Examples

    frame = Kino.Frame.new() |> Kino.render()

    for i <- 1..100 do
      Kino.Frame.render(frame, i)
      Process.sleep(50)
    end

Or with a scheduled task in the background.

    frame = Kino.Frame.new() |> Kino.render()

    Kino.listen(50, fn i ->
      Kino.Frame.render(frame, i)
    end)

## new/1

Creates a new frame.

## Options

  * `:placeholder` - whether to render a placeholder when the frame
    is empty. Defaults to `true`

## render/3

Renders the given term within the frame.

This works similarly to `Kino.render/1`, but the rendered
output replaces existing frame contents.

## Options

  * `:to` - the client id to whom the update is directed. This
    option is useful when updating frame in response to client
    events, such as form submission

  * `:temporary` - when `true`, the update is applied only to
    the connected clients and doesn't become a part of frame
    history. Defaults to `false`, unless `:to` is given. Direct
    updates are never a part of frame history

## append/3

Renders and appends the given term to the frame.

## Options

  * `:to` - the client id to whom the update is directed. This
    option is useful when updating frame in response to client
    events, such as form submission

  * `:temporary` - when `true`, the update is applied only to
    the connected clients and doesn't become a part of frame
    history. Defaults to `false`, unless `:to` is given. Direct
    updates are never a part of frame history

## clear/2

Removes all outputs within the given frame.

## Options

  * `:to` - the client id to whom the update is directed. This
    option is useful when updating frame in response to client
    events, such as form submission

  * `:temporary` - when `true`, the update is applied only to
    the connected clients and doesn't become a part of frame
    history. Defaults to `false`, unless `:to` is given. Direct
    updates are never a part of frame history