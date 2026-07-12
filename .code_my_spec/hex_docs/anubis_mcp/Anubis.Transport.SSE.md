# Anubis.Transport.SSE

A transport implementation that uses Server-Sent Events (SSE) for receiving messages
and HTTP POST requests for sending messages back to the server.

> #### Deprecated {: .warning}
>
> This transport has been deprecated as of MCP specification 2025-03-26 in favor
> of the Streamable HTTP transport (`Anubis.Transport.StreamableHTTP`).
>
> The HTTP+SSE transport from protocol version 2024-11-05 has been replaced by
> the more flexible Streamable HTTP transport which supports optional SSE streaming
> on a single endpoint.
>
> For new implementations, please use `Anubis.Transport.StreamableHTTP` instead.
> This module is maintained for backward compatibility with servers using the
> 2024-11-05 protocol version.

> ## Notes {: .info}
>
> For initialization and setup, check our [Installation & Setup](./installation.html) and
> the [Transport options](./transport_options.html) guides for reference.