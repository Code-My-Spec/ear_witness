# Kino.JS.Live.Context

State available in `Kino.JS.Live` server callbacks.

## Properties

  * `:assigns` - custom server state kept across callback calls

  * `:origin` - an opaque identifier of the client that triggered
    the given action. It is set in `c:Kino.JS.Live.handle_connect/1`
    and `c:Kino.JS.Live.handle_event/3`

## assign/2

Stores key-value pairs in the state.

## Examples

    assign(ctx, count: 1, timestamp: DateTime.utc_now())

## update/3

Updates an existing key with the given function in the state.

## Examples

    update(ctx, :count, &(&1 + 1))

## broadcast_event/3

Sends an event to all clients.

The event is dispatched to the registered JavaScript callback
on all connected clients.

## Examples

    broadcast_event(ctx, "new_point", %{x: 10, y: 10})

## send_event/4

Sends an event to a specific client.

The event is dispatched to the registered JavaScript callback
on the specific connected client.

## Examples

    send_event(ctx, origin, "new_point", %{x: 10, y: 10})

## emit_event/2

Emits an event to processes subscribed to this kino.

Consumers may subscribe to events emitted by the given instance of
`Kino.JS.Live` using functions in the `Kino.Control` module, such
as `Kino.Control.stream/1`.

## Examples

    emit_event(ctx, %{event: :click, counter: 1})

## reconfigure_smart_cell/2

Updates smart cell configuration.

This function allows for re-configuring some of the options that can
be specified in smart cell's `c:Kino.JS.Live.init/2`.

Note that this function returns the new context, which you should
return from the given handler.

## Options

  * `:editor` - note that the smart cell must be initialized with an
    editor during init. Supported options: `:source`, `:intellisense_node`,
    `:visible`