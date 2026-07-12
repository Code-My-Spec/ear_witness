# Anubis.Transport.StreamableHTTP

A transport implementation that uses Streamable HTTP as specified in MCP 2025-03-26.

This transport communicates with MCP servers via HTTP POST requests for sending messages
and optionally uses Server-Sent Events (SSE) for receiving streaming responses.

## Usage

    # Start the transport with a base URL
    {:ok, transport} = Anubis.Transport.StreamableHTTP.start_link(
      client: client_pid,
      base_url: "http://localhost:8000",
      mcp_path: "/mcp"
    )

    # Send a message
    :ok = Anubis.Transport.StreamableHTTP.send_message(transport, encoded_message)

## Session Management

The transport automatically handles MCP session IDs via the `mcp-session-id` header:
- Extracts session ID from server responses
- Includes session ID in subsequent requests
- Maintains session state throughout the connection lifecycle
- Handles session expiration (404 responses) by reinitializing

## Response Handling

Based on the response status and content type:
- 202 Accepted: Message acknowledged, no immediate response
- 200 OK with application/json: Single JSON response forwarded to client
- 200 OK with text/event-stream: SSE stream parsed and events forwarded to client
- 404 Not Found: Session expired, triggers reinitialization

## SSE Support

The transport can establish a separate GET connection for server-initiated messages.
This allows the server to send requests and notifications without a client request.