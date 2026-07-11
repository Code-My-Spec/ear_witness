# Kino.Control

Various widgets for user interactions.

Each widget is a UI control element that the user interacts
with, consequently producing an event stream.

Those widgets are often useful paired with `Kino.Frame` for
presenting content that changes upon user interactions.

## Examples

First, create a control and make sure it is rendered,
either by placing it at the end of a code cell or by
explicitly rendering it with `Kino.render/1`.

    button = Kino.Control.button("Hello")

Next, events need to be received from the control. This can
be done either by subscribing a process to the control with
`subscribe/2` or by creating an event stream using `stream/1`
or `tagged_stream/1` and then registering a callback using
`Kino.listen/2`.

Here, we'll subscribe the current process to events:

    Kino.Control.subscribe(button, :hello)

As the user clicks the button, the subscribed process
receives events:

    IEx.Helpers.flush()
    #=> {:hello, %{origin: "client1"}}
    #=> {:hello, %{origin: "client1"}}

## button/1

Creates a new button.

## Examples

Create the widget:

    button = Kino.Control.button("Hello")

Listen to events:

    Kino.listen(button, fn event ->
      ...
    end)

Or subscribe to them in a separate process:

    Kino.Control.subscribe(button, :keyboard)

## keyboard/2

Creates a new keyboard control.

This widget is represented as button that toggles interception
mode, in which the given keyboard events are captured.

> #### Keyboard shortcut {:.info}
>
> As of Livebook v0.11, keyboard controls can be toggled by
> focusing the cell and pressing `ctrl + k` (or `⌘ + k` on
> MacOS).

## Options

Note that these options require Livebook v0.11 or later.

  * `:default_handlers` - controls Livebook's default keyboard
    shortcut handlers while the keyboard control is enabled.
    Must be one of:

    * `:off` (default) - all Livebook keyboard shortcuts are disabled

    * `:on` - all Livebook keyboard shortcuts are enabled

    * `:disable_only` - Livebook keyboard shortcuts are off except
      for the shortcut to toggle (disable) the control

## Event info

In addition to standard properties, all events include additional
properties.

### Key events

  * `:type` - either `:keyup` or `:keydown`

  * `:key` - the value matching the browser [KeyboardEvent.key](https://developer.mozilla.org/en-US/docs/Web/API/KeyboardEvent/key)

### Status event

  * `:type` - either `:status`

  * `:enabled` - whether the keyboard is activated

## Examples

Create the widget:

    keyboard = Kino.Control.keyboard([:keyup, :keydown, :status])

Listen to events:

    Kino.listen(keyboard, fn event ->
      ...
    end)

Or subscribe to them in a separate process:

    Kino.Control.subscribe(keyboard, :keyboard)

As the user types events are streamed:

    IEx.Helpers.flush()
    #=> {:keyboard, %{enabled: true, origin: "client1", type: :status}
    #=> {:keyboard, %{key: "o", origin: "client1", type: :keydown}}
    #=> {:keyboard, %{key: "k", origin: "client1", type: :keydown}}
    #=> {:keyboard, %{key: "o", origin: "client1", type: :keyup}}
    #=> {:keyboard, %{key: "k", origin: "client1", type: :keyup}}

## form/2

Creates a new form.

A form is composed of regular inputs from the `Kino.Input` module,
however in a form, input values are not synchronized between users.
Instead the form emits user-specific events with the input values.

The first argument is a keyword list of fields, where the value is
either an input or nil. If the value is nil, it means the data has
the input value set to nil too. This is useful in cases where the
forms inputs may be generated dynamically.

Either `:submit` or `:report_changes` must be specified as option.

## Options

  * `:submit` - specifies the label to use for the submit button
    and enables submit events

  * `:report_changes` - whether to send new form value whenever any
    of the input changes. Defaults to `false`

  * `:reset_on_submit` - a list of fields to revert to their default
    values once the form is submitted. Use `true` to indicate all
    fields. Defaults to `[]`

## Event info

In addition to standard properties, all events include additional
properties.

  * `:type` - either `:submit` or `:change`

  * `:data` - a map with field values, matching the field list

## Examples

Create a form out of inputs:

    form =
      Kino.Control.form(
        [
          name: Kino.Input.text("Name"),
          message: Kino.Input.textarea("Message")
        ],
        submit: "Send"
      )

Listen to events:

    Kino.listen(form, fn event ->
      ...
    end)

Or subscribe to them in a separate process:

    Kino.Control.subscribe(form, :chat_form)

As users submit the form the payload is sent:

    IEx.Helpers.flush()
    #=> {:chat_form,
    #=>   %{
    #=>     data: %{message: "Hola", name: "Amy"},
    #=>     origin: "client1",
    #=>     type: :submit
    #=>   }}
    #=> {:chat_form,
    #=>   %{
    #=>     data: %{message: "Hey!", name: "Jake"},
    #=>     origin: "client2",
    #=>     type: :submit
    #=>   }}

## subscribe/2

Subscribes the calling process to control, input, or `Kino.JS.Live` events.

This is an alternative API to `stream/1`, such that event
messages are consumed via process messages instead of streams.

The events are sent as `{tag, info}`, where info is a map with
event details. In particular, it always includes `:origin`, which
is an opaque identifier of the client that triggered the event.

## unsubscribe/1

Unsubscribes the calling process from control, input, or `Kino.JS.Live` events.

## interval/1

Returns a new interval event source.

This can be used as event source for `stream/1` and `tagged_stream/1`.
The events are emitted periodically with an increasing value, starting
from 0 and have the form:

    %{type: :interval, iteration: non_neg_integer()}

## stream/1

Merges several inputs and controls into a single `stream` of events.

It accepts a single source or a list of sources, where each
source is either of:

  * `%Kino.Control{}` - emitting value on relevant interaction

  * `%Kino.Input{}` - emitting value on value change

  * `%Kino.JS.Live{}` - emitting value programmatically

  * `t:interval/0` - emitting value periodically, see `interval/1`

You can then consume the stream to access its events.
The stream is typically consumed via `Kino.listen/2`.

## Example

    button = Kino.Control.button("Hello")
    input = Kino.Input.checkbox("Check")
    interval = Kino.Control.interval(1000)

    [button, input, interval]
    |> Kino.Control.stream()
    |> Kino.listen(fn event ->
      IO.inspect(event)
    end)
    #=> %{type: :interval, iteration: 0}
    #=> %{origin: "client1", type: :click}
    #=> %{origin: "client1", type: :change, value: true}

## tagged_stream/1

Same as `stream/1`, but attaches custom tag to every stream item.

Tags can be arbitrary terms.

## Example

    button = Kino.Control.button("Hello")
    input = Kino.Input.checkbox("Check")

    [hello: button, check: input]
    |> Kino.Control.tagged_stream()
    |> Kino.listen(fn event ->
      IO.inspect(event)
    end)
    #=> {:hello, %{origin: "client1", type: :click}}
    #=> {:check, %{origin: "client1", type: :change, value: true}}