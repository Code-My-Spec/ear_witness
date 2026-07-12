# Anubis.Server.Transport.SSE

SSE (Server-Sent Events) transport implementation for MCP servers.

> #### Deprecated {: .warning}
>
> This transport has been deprecated as of MCP specification 2025-03-26 in favor
> of the Streamable HTTP transport (`Anubis.Server.Transport.StreamableHTTP`).
>
> The HTTP+SSE transport from protocol version 2024-11-05 has been replaced by
> the more flexible Streamable HTTP transport which supports optional SSE streaming
> on a single endpoint.
>
> For new implementations, please use `Anubis.Server.Transport.StreamableHTTP` instead.
> This module is maintained for backward compatibility with clients using the
> 2024-11-05 protocol version.

This module provides backward compatibility with the HTTP+SSE transport
from MCP protocol version 2024-11-05. It supports multiple concurrent
client sessions through Server-Sent Events for server-to-client communication
and HTTP POST for client-to-server messages.

## Features

- Multiple concurrent client sessions
- Server-Sent Events for real-time server-to-client communication
- Separate SSE and POST endpoints (as per 2024-11-05 spec)
- Automatic session cleanup on disconnect
- Integration with existing Phoenix/Plug applications

## Usage

SSE transport is typically started through the server supervisor:

    Anubis.Server.start_link(MyServer, [],
      transport: :sse,
      sse: [port: 8080, sse_path: "/sse", post_path: "/messages"]
    )

For integration with existing Phoenix/Plug applications:

    # In your router
    forward "/sse", Anubis.Server.Transport.SSE.Plug,
      server: MyApp.MCPServer,
      mode: :sse

    forward "/messages", Anubis.Server.Transport.SSE.Plug,
      server: MyApp.MCPServer,
      mode: :post

## Message Flow

1. Client connects to SSE endpoint, receives "endpoint" event with POST URL
2. Client sends messages via POST to the endpoint URL
3. Server responses are pushed through the SSE connection
4. Connection closes on client disconnect or server shutdown

## Configuration

- `:port` - HTTP server port (default: 8080)
- `:sse_path` - Path for SSE connections (default: "/sse")
- `:post_path` - Path for POST messages (default: "/messages")
- `:server` - The MCP server process to connect to
- `:name` - Process registration name

## start_link/1

Starts the SSE transport.

## send_message/3

Sends a message to the client via the active SSE connection.

This broadcasts to all active SSE connections for the session.

## Parameters
  * `transport` - The transport process
  * `message` - The message to send

## Returns
  * `:ok` if message was sent successfully
  * `{:error, reason}` otherwise

## shutdown/1

Shuts down the transport connection.

This terminates all active sessions managed by this transport.

## Parameters
  * `transport` - The transport process

## register_sse_handler/2

Registers an SSE handler process for a session.

Called by the Plug when establishing an SSE connection.
The calling process becomes the SSE handler for the session.

## unregister_sse_handler/2

Unregisters an SSE handler process for a session.

Called when the SSE connection is closed.

## handle_message/4

Handles an incoming message from a client with request context.

Called by the Plug when a message is received via HTTP POST.

## get_sse_handler/2

Gets the SSE handler process for a session.

Returns the pid of the process handling SSE for this session,
or nil if no SSE connection exists.

## route_to_session/3

Routes a message to a specific session's SSE handler.

Used for targeted server notifications to specific clients.

## get_endpoint_url/1

Gets the endpoint URL that should be sent to clients.

This constructs the URL that clients should use for POST requests.