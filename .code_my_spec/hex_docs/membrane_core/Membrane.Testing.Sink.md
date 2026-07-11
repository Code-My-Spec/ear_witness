# Membrane.Testing.Sink

Sink Element that notifies the pipeline about buffers and events it receives.

By default `Sink` will demand buffers automatically, but you can override that
behaviour by using `autodemand` option. If set to false no automatic demands
shall be made. Demands can be then triggered by sending `{:make_demand, size}`
message.

This element can be used in conjunction with `Membrane.Testing.Pipeline` to
enable asserting on buffers and events it receives.

    alias Membrane.Testing
    links = [
        ... |>
        child(:sink, %Testing.Sink{}) |>
        ...
    ]
    {:ok, pid} = Testing.Pipeline.start_link(
      spec: links
    )

Asserting that `Membrane.Testing.Sink` element processed a buffer that matches
a specific pattern can be achieved using
`Membrane.Testing.Assertions.assert_sink_buffer/3`.

    assert_sink_buffer(pid, :sink ,%Membrane.Buffer{payload: 255})