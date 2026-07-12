# Anubis.Server.Transport.StreamableHTTP.Plug

A Plug implementation for the Streamable HTTP transport.

This plug handles the MCP Streamable HTTP protocol as specified in MCP 2025-03-26.
It provides a single endpoint that supports both GET and POST methods:

- GET: Opens an SSE stream for server-to-client communication
- POST: Handles JSON-RPC messages from client to server
- DELETE: Closes a session

## Usage in Phoenix Router

    pipeline :mcp do
      plug :accepts, ["json"]
    end

    scope "/mcp" do
      pipe_through :mcp
      forward "/", to: Anubis.Server.Transport.StreamableHTTP.Plug, server: :your_server_name
    end

## Configuration Options

- `:server` - The server process name (required)
- `:session_header` - Custom header name for session ID (default: "mcp-session-id")
- `:request_timeout` - Request timeout in milliseconds (default: 30000)