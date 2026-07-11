# Kino.Test

Conveniences for testing custom Kino components.

In practice, `Kino.JS.Live` kinos communicate with Livebook via
the group leader. During tests, Livebook is out of the equation,
so we need to mimic this side of the communication. To do so, add
the following setup to your test module:

    import Kino.Test

    setup :configure_livebook_bridge

## assert_output/2

Asserts the given output is sent within `timeout`.

## Examples

    assert_output({:markdown, "_hey_"})

## assert_output_to/3

Asserts the given output is sent directly to the given client within
`timeout`.

## Examples

    assert_output_to("client1", {:markdown, "_hey_"})

## assert_output_to_clients/2

Asserts the given output is sent directly to all clients within `timeout`.

## Examples

    assert_output_to("client1", {:markdown, "_hey_"})

## assert_broadcast_event/4

Asserts a `Kino.JS.Live` kino will broadcast an event within
`timeout`.

## Examples

    assert_broadcast_event(kino, "bump", %{by: 2})

## assert_send_event/4

Asserts a `Kino.JS.Live` kino will send an event within `timeout`
to the caller.

## Examples

    assert_send_event(kino, "pong", %{})

## push_event/3

Sends a client event to a `Kino.JS.Live` kino.

## Examples

    push_event(kino, "bump", %{"by" => 2})

## connect/3

Connects to a `Kino.JS.Live` kino and returns the initial data.

If `resolve_fun` is given, it runs after sending the connection
request and before awaiting for the reply.

## Examples

    data = connect(kino)
    assert data == %{count: 1}

## start_smart_cell!/2

Starts a smart cell defined by the given module.

Returns a `Kino.JS.Live` kino for interacting with the cell, as
well as the initial source.

## Examples

    {kino, source} = start_smart_cell!(Kino.SmartCell.Custom, %{"key" => "value"})

## push_smart_cell_editor_source/2

Sends a changed smart cell editor source to a `Kino.JS.Live` kino.

This is going to call `c:Kino.SmartCell.handle_editor_change/2` implementation
in the smart cell module.

## Examples

    push_smart_cell_editor_source(kino, "source code")

## export/2

Invokes export for the given `Kino.JS` or `Kino.JS.Live` and returns
the result.

For more details, see `Kino.JS.new/3` and `Kino.JS.Live.new/3`
respectively.