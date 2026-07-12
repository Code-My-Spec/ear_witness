# Anubis.SSE.Streaming



## start/4

Starts the SSE streaming loop for a connection.

This function takes control of the connection and enters a receive loop,
streaming messages to the client as they arrive.

## Parameters
  - `conn` - The Plug.Conn that has been prepared for chunked response
  - `transport` - The transport process
  - `session_id` - The session identifier
  - `opts` - Options including:
    - `:initial_event_id` - Starting event ID (default: 0)
    - `:on_close` - Function to call when connection closes

## Messages handled
  - `{:sse_message, binary}` - Message to send to client
  - `:close_sse` - Close the connection gracefully

## prepare_connection/1

Prepares a connection for SSE streaming.

Sets appropriate headers and starts chunked response.

## send_event/3

Sends a single SSE event.

This is useful for sending events outside of the main loop.