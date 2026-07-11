# Membrane.Testing.Assertions

This module contains a set of assertion functions and macros.

These assertions will work ONLY in conjunction with
`Membrane.Testing.Pipeline` and ONLY when pid of tested pipeline is provided
as an argument to these assertions.

## assert_pipeline_notified/4

Asserts that pipeline received or will receive a notification from the element
with name `element_name` within the `timeout` period specified in milliseconds.

The `notification_pattern` must be a match pattern.

    assert_pipeline_notified(pipeline, :element_name, :hi)

## refute_pipeline_notified/4

Refutes that pipeline received or will receive a notification from the element
with name `element_name` within the `timeout` period specified in milliseconds.

The `notification_pattern` must be a match pattern.

    refute_pipeline_notified(pipeline, :element_name, :hi)

## assert_pipeline_crash_group_down/3

Asserts that a crash group within pipeline will be down within the `timeout` period specified in
milliseconds.

Usage example:

    assert_pipeline_crash_group_down(pipeline, :group_1)

## refute_pipeline_crash_group_down/3

Asserts that a crash group within pipeline won't be down within the `timeout` period specified in
milliseconds.

Usage example:

    refute_pipeline_crash_group_down(pipeline, :group_1)

## assert_pipeline_receive/3

Asserts that pipeline received or will receive a message matching
`message_pattern` from another process within the `timeout` period specified
in milliseconds.

The `message_pattern` must be a match pattern.

    assert_pipeline_receive(pid, :tick)

Such call would flunk if the message `:tick` has not been handled by
`c:Membrane.Parent.handle_info/3` within the `timeout`.

## refute_pipeline_receive/3

Asserts that pipeline has not received and will not receive a message from
another process matching `message_pattern` within the `timeout` period
specified in milliseconds.

The `message_pattern` must be a match pattern.


    refute_pipeline_receive(pid, :tick)


Such call would flunk if the message `:tick` has been handled by
`c:Membrane.Parent.handle_info/3`.

## assert_sink_stream_format/4

Asserts that `Membrane.Testing.Sink` with name `sink_name` received or will
receive stream format matching `pattern` within the `timeout` period specified in
milliseconds.

When the `Membrane.Testing.Sink` is a part of `Membrane.Testing.Pipeline` you
can assert whether it received stream format matching provided pattern.
    import Membrane.ChildrenSpec
    children = [
        ...,
        child(:the_sink, %Membrane.Testing.Sink{})
    ]
    {:ok, pid} = Membrane.Testing.Pipeline.start_link(
      spec: children,
    )

You can match for exact value:

    assert_sink_stream_format(pid, :the_sink , %StreamFormat{prop: ^value})

You can also use pattern to extract data from the stream_format:

    assert_sink_stream_format(pid, :the_sink , %StreamFormat{prop: value})
    do_something(value)

## refute_sink_stream_format/4

Asserts that `Membrane.Testing.Sink` with name `sink_name` has not received
and will not receive stream format matching `stream_format_pattern` within the `timeout`
period specified in milliseconds.

Similarly as in the `assert_sink_stream_format/4` `the_sink` needs to be part of a
`Membrane.Testing.Pipeline`.

    refute_sink_stream_format(pipeline, :the_sink, %StreamFormat{prop: ^val})

Such expression will flunk if `the_sink` received or will receive stream_format with
property equal to value of `val` variable.

## assert_sink_buffer/4

Asserts that `Membrane.Testing.Sink` with name `sink_name` received or will
receive a buffer matching `pattern` within the `timeout` period specified in
milliseconds.

When the `Membrane.Testing.Sink` is a part of `Membrane.Testing.Pipeline` you
can assert whether it received a buffer matching provided pattern.
    import Membrane.ChildrenSpec
    spec = [
        ...
        |> child(:the_sink, %Membrane.Testing.Sink{}) |>
        ...
    ]
    {:ok, pid} = Membrane.Testing.Pipeline.start_link(
      spec: spec,
    )

You can match for exact value:

    assert_sink_buffer(pid, :the_sink ,%Membrane.Buffer{payload: ^specific_payload})

You can also use pattern to extract data from the buffer:

    assert_sink_buffer(pid, :sink, %Buffer{payload: <<data::16>> <> <<255>>})
    do_something(data)

## refute_sink_buffer/4

Asserts that `Membrane.Testing.Sink` with name `sink_name` has not received
and will not receive a buffer matching `buffer_pattern` within the `timeout`
period specified in milliseconds.

Similarly as in the `assert_sink_buffer/4` `the_sink` needs to be part of a
`Membrane.Testing.Pipeline`.

    refute_sink_buffer(pipeline, :the_sink, %Buffer{payload: <<0xA1, 0xB2>>})

Such expression will flunk if `the_sink` received or will receive a buffer
with payload `<<0xA1, 0xB2>>`.

## assert_sink_event/4

Asserts that `Membrane.Testing.Sink` with name `sink_name` received or will
receive an event within the `timeout` period specified in milliseconds.

When a `Membrane.Testing.Sink` is part of `Membrane.Testing.Pipeline` you can
assert whether it received an event matching a provided pattern.

    assert_sink_event(pid, :the_sink, %Discontinuity{})

## refute_sink_event/4

Asserts that `Membrane.Testing.Sink` has not received and will not receive
event matching provided pattern within the `timeout` period specified in
milliseconds.

    refute_sink_event(pid, :the_sink, %Discontinuity{})

## assert_sink_playing/3

Asserts that `Membrane.Testing.Sink` with name `sink_name` entered the playing
playback.

## refute_sink_playing/3

Asserts that `Membrane.Testing.Sink` with name `sink_name` didn't enter the playing
playback.

## assert_start_of_stream/4

Asserts that `Membrane.Testing.Pipeline` received or is going to receive start_of_stream
notification from the element with a name `element_name` within the `timeout` period
specified in milliseconds.

    assert_start_of_stream(pipeline, :an_element)

## assert_end_of_stream/4

Asserts that `Membrane.Testing.Pipeline` received or is going to receive end_of_stream
notification about from the element with a name `element_name` within the `timeout` period
specified in milliseconds.

    assert_end_of_stream(pipeline, :an_element)

## assert_child_pad_removed/4

Asserts that `Membrane.Testing.Pipeline` child with name `child` removed or is going to
remove it's pad with ref `pad` within the `timeout` period specified in milliseconds.

## assert_resource_guard_register/4

Asserts that a cleanup function was registered in `Membrane.Testing.MockResourceGuard`.

## assert_resource_guard_unregister/3

Asserts that a tag was unregistered in `Membrane.Testing.MockResourceGuard`.

## assert_resource_guard_cleanup/3

Asserts that `Membrane.Testing.MockResourceGuard` was requested to cleanup a given tag.