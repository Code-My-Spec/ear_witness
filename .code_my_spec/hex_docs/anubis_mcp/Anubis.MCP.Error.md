# Anubis.MCP.Error

Fluent API for building MCP protocol errors.

This module provides a semantic interface for creating errors that comply with
the MCP specification and JSON-RPC 2.0 error standards.

## Error Categories

- **Protocol Errors**: Standard JSON-RPC errors (parse, invalid request, etc.)
- **Transport Errors**: Connection and communication issues
- **Resource Errors**: MCP-specific resource handling errors
- **Execution Errors**: Tool and operation execution failures

## Examples

    # Protocol errors
    Anubis.MCP.Error.protocol(:parse_error)
    Anubis.MCP.Error.protocol(:method_not_found, %{method: "unknown"})

    # Transport errors
    Anubis.MCP.Error.transport(:connection_refused)
    Anubis.MCP.Error.transport(:timeout, %{elapsed_ms: 30000})

    # Resource errors
    Anubis.MCP.Error.resource(:not_found, %{uri: "file:///missing.txt"})

    # Execution errors with custom messages
    Anubis.MCP.Error.execution("Database connection failed", %{retries: 3})

    # Converting from JSON-RPC
    Anubis.MCP.Error.from_json_rpc(%{"code" => -32700, "message" => "Parse error"})

## protocol/2

Creates a protocol-level error.

These are standard JSON-RPC errors that occur during message parsing and validation.

## Supported Reasons

- `:parse_error` - Invalid JSON was received
- `:invalid_request` - The JSON is not a valid Request object
- `:method_not_found` - The method does not exist
- `:invalid_params` - Invalid method parameters
- `:internal_error` - Internal JSON-RPC error

## Examples

    iex> Anubis.MCP.Error.protocol(:parse_error)
    %Anubis.MCP.Error{code: -32700, reason: :parse_error, message: "Parse error", data: %{}}

    iex> Anubis.MCP.Error.protocol(:method_not_found, %{method: "foo"})
    %Anubis.MCP.Error{code: -32601, reason: :method_not_found, message: "Method not found", data: %{method: "foo"}}

## transport/2

Creates a transport-level error.

Used for network, connection, and communication failures.

## Examples

    iex> Anubis.MCP.Error.transport(:connection_refused)
    %Anubis.MCP.Error{code: -32000, reason: :connection_refused, message: "Connection Refused", data: %{}}

    iex> Anubis.MCP.Error.transport(:timeout, %{elapsed_ms: 5000})
    %Anubis.MCP.Error{code: -32000, reason: :timeout, message: "Timeout", data: %{elapsed_ms: 5000}}

## resource/2

Creates a resource-specific error.

Used for MCP resource operations.

## Examples

    iex> Anubis.MCP.Error.resource(:not_found, %{uri: "file:///missing.txt"})
    %Anubis.MCP.Error{code: -32002, reason: :resource_not_found, message: "Resource not found", data: %{uri: "file:///missing.txt"}}

## execution/2

Creates an execution error with a custom message.

Used for tool execution failures and domain-specific errors.

## Examples

    iex> Anubis.MCP.Error.execution("Database connection failed")
    %Anubis.MCP.Error{code: -32000, reason: :execution_error, message: "Database connection failed", data: %{}}

    iex> Anubis.MCP.Error.execution("API rate limit exceeded", %{retry_after: 60})
    %Anubis.MCP.Error{code: -32000, reason: :execution_error, message: "API rate limit exceeded", data: %{retry_after: 60}}

## from_json_rpc/1

Creates an error from a JSON-RPC error object.

## Examples

    iex> Anubis.MCP.Error.from_json_rpc(%{"code" => -32700, "message" => "Parse error"})
    %Anubis.MCP.Error{code: -32700, reason: :parse_error, message: "Parse error", data: %{}}

    iex> Anubis.MCP.Error.from_json_rpc(%{"code" => -32002, "message" => "Not found", "data" => %{"uri" => "/file"}})
    %Anubis.MCP.Error{code: -32002, reason: :resource_not_found, message: "Not found", data: %{"uri" => "/file"}}

## to_json_rpc/2

Encodes the error as a JSON-RPC error response.

## Examples

    iex> error = Anubis.MCP.Error.protocol(:parse_error)
    iex> {:ok, encoded} = Anubis.MCP.Error.to_json_rpc(error, "req-123")
    iex> String.contains?(encoded, "Parse error")
    true