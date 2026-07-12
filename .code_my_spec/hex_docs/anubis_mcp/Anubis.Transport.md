# Anubis.Transport

Functional behaviour for MCP transport implementations.

Unlike `Anubis.Transport.Behaviour` (which defines a GenServer-oriented transport
interface), this behaviour defines a **functional** transport interface for
parsing, encoding, sending messages, and extracting metadata.

Transport modules implementing this behaviour provide pure functions for
message framing — the actual I/O process (Port, Plug conn, SSE handler) already
exists and calls these functions internally.

## Adapters

- `Anubis.Transport.STDIO` — newline-delimited JSON over stdin/stdout (client)
- `Anubis.Transport.StreamableHTTP` — JSON over HTTP request/response bodies (client)
- `Anubis.Transport.SSE` — JSON wrapped in SSE event format (client)

## Example

    {:ok, state} = MyTransport.transport_init(opts)
    {:ok, message, state} = MyTransport.parse(raw_data, state)
    {:ok, encoded, state} = MyTransport.encode(response, state)