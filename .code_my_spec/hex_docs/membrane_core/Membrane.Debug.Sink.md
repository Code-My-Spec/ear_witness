# Membrane.Debug.Sink

Membrane Sink, that can be used to create a child that will be used to debug data flowing thouth pipeline.

Usage example:
```elixir
child(:source, CustomSource)
|> child(:sink, %Membrane.Debug.Sink{
  handle_buffer: &IO.inspect(&1, label: "buffer"),
  handle_event: &IO.inspect(&1, label: "event")
})
```