# Anubis.Server.Transport.SSE.Plug

A Plug implementation for the SSE (Server-Sent Events) transport.

> #### Deprecated {: .warning}
>
> This Plug has been deprecated as of MCP specification 2025-03-26 in favor
> of the Streamable HTTP transport (`Anubis.Server.Transport.StreamableHTTP.Plug`).
>
> The HTTP+SSE transport from protocol version 2024-11-05 has been replaced by
> the more flexible Streamable HTTP transport which supports optional SSE streaming
> on a single endpoint.
>
> For new implementations, please use `Anubis.Server.Transport.StreamableHTTP.Plug` instead.
> This module is maintained for backward compatibility with clients using the
> 2024-11-05 protocol version.

This plug handles the MCP HTTP+SSE protocol as specified in MCP 2024-11-05.
It provides two separate endpoints:

- SSE endpoint: Opens an SSE stream and sends "endpoint" event
- POST endpoint: Handles JSON-RPC messages from client to server

## SSE Streaming Architecture

This Plug handles SSE streaming by keeping the request process alive 
and managing the streaming loop for server-to-client communication.

## Usage in Phoenix Router

    pipeline :mcp do
      plug :accepts, ["json", "event-stream"]
    end

    scope "/mcp" do
      pipe_through :mcp

      # SSE endpoint
      get "/sse", Anubis.Server.Transport.SSE.Plug,
        server: :your_server_name, mode: :sse

      # POST endpoint
      post "/messages", Anubis.Server.Transport.SSE.Plug,
        server: :your_server_name, mode: :post
    end

## Usage in Plug Router (Standalone)

    # When using in a standalone Plug.Router app
    plug Anubis.Server.Transport.SSE.Plug,
      server: :your_server_name,
      mode: :sse,
      at: "/sse",
      method_whitelist: ["GET"]

    plug Anubis.Server.Transport.SSE.Plug,
      server: :your_server_name,
      mode: :post,
      at: "/messages",
      method_whitelist: ["POST"]

## Configuration Options

- `:server` - The server process name (required)
- `:mode` - Either `:sse` or `:post` to determine endpoint behavior (required)
- `:timeout` - Request timeout in milliseconds (default: 30000)
- `:registry` - The registry to use. See `Anubis.Server.Registry.Adapter` for more information (default: Elixir's Registry implementation)

## Security Features

- Origin header validation for DNS rebinding protection
- Session-based request validation
- Automatic session cleanup on connection loss

## HTTP Response Codes

- 200: Successful request or SSE stream established
- 202: Accepted (for notifications)
- 400: Bad request (malformed JSON-RPC)
- 405: Method not allowed
- 500: Internal server error