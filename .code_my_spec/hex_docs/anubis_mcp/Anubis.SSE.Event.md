# Anubis.SSE.Event



## encode/1

Encodes SSE events into the wire format.

## Examples

    iex> event = %Anubis.SSE.Event{data: "hello"}
    iex> inspect(event)
    "event: message\ndata: hello\n\n"
    
    iex> event = %Anubis.SSE.Event{id: "123", event: "ping", data: "pong"}
    iex> inspect(event)
    "id: 123\nevent: ping\ndata: pong\n\n"