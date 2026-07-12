# Anubis.Server.Transport.StreamableHTTP

StreamableHTTP transport implementation for MCP servers.

This module manages SSE (Server-Sent Events) connections for server-to-client
communication. In the refactored architecture, request handling is done directly
by Session processes - this module only manages SSE handlers and notifications.

## Features

- SSE handler registration for server-to-client push
- Automatic handler cleanup on disconnect
- Keepalive messages to maintain connections
- Notification broadcasting to connected clients

## Usage

StreamableHTTP is typically started through the server supervisor:

    Anubis.Server.start_link(MyServer, [],
      transport: :streamable_http,
      streamable_http: [port: 4000]
    )

For integration with existing Phoenix/Plug applications:

    # In your router
    forward "/mcp", Anubis.Server.Transport.StreamableHTTP.Plug,
      server: MyApp.MCPServer

## register_sse_handler/2

Registers the calling process as the SSE handler for a session.

Called by the Plug when establishing an SSE connection.

## unregister_sse_handler/3

Unregisters the SSE handler for a session. Called when the SSE connection closes.

## get_sse_handler/2

Returns the SSE handler pid for a session, or `nil` if none is connected.

## route_to_session/3

Routes a message to a specific session's SSE handler for server-to-client push.