# Anubis.MCP.Response

Represents successful responses in the MCP protocol.

This module provides a wrapper around JSON-RPC responses, handling
domain-specific error semantics for MCP's "isError" field in results.

## Response Structure

Each response includes:
- `result`: The response data from the server
- `id`: The request ID this response is associated with
- `is_error`: Boolean flag indicating if this is a domain-level error

## Domain vs. Protocol Errors

The MCP protocol distinguishes between two types of errors:

1. Protocol errors: Standard JSON-RPC errors with error codes (handled by `Anubis.MCP.Error`)
2. Domain errors: Valid responses that indicate application-level errors with `isError: true`

This module specifically handles domain errors, which are successful at the protocol level
but indicate failures at the application level.

## Examples

```elixir
# Create from a JSON-RPC response
response = Anubis.MCP.Response.from_json_rpc(%{"result" => %{"data" => "value"}, "id" => "req_123"})

# Check if the response is successful or has a domain error
if Anubis.MCP.Response.success?(response) do
  # Handle success
else
  # Handle domain error
end

# Unwrap the response to get the result or error
case Anubis.MCP.Response.unwrap(response) do
  {:ok, result} -> # Handle success
  {:error, error} -> # Handle domain error
end
```

## from_json_rpc/1

Creates a Response struct from a JSON-RPC response.

Automatically detects domain errors by checking for the "isError" field.

## Parameters

  * `response` - A map containing the JSON-RPC response

## Examples

    iex> Anubis.MCP.Response.from_json_rpc(%{"result" => %{}, "id" => "req_123"})
    %Anubis.MCP.Response{result: %{}, id: "req_123", is_error: false}
    
    iex> Anubis.MCP.Response.from_json_rpc(%{"result" => %{"isError" => true}, "id" => "req_123"})
    %Anubis.MCP.Response{result: %{"isError" => true}, id: "req_123", is_error: true}

## unwrap/1

Unwraps the response, returning the raw result.

Returns the raw result data regardless of whether it represents
a success or domain error.

## Examples

    iex> response = Anubis.MCP.Response.from_json_rpc(%{"result" => %{"data" => "value"}, "id" => "req_123"})
    iex> Anubis.MCP.Response.unwrap(response)
    %{"data" => "value"}
    
    iex> error_response = Anubis.MCP.Response.from_json_rpc(%{"result" => %{"isError" => true, "reason" => "not_found"}, "id" => "req_123"})
    iex> Anubis.MCP.Response.unwrap(error_response)
    %{"isError" => true, "reason" => "not_found"}

## success?/1

Checks if the response is successful (no domain error).

## Examples

    iex> response = Anubis.MCP.Response.from_json_rpc(%{"result" => %{"data" => "value"}, "id" => "req_123"})
    iex> Anubis.MCP.Response.success?(response)
    true
    
    iex> error_response = Anubis.MCP.Response.from_json_rpc(%{"result" => %{"isError" => true}, "id" => "req_123"})
    iex> Anubis.MCP.Response.success?(error_response)
    false

## error?/1

Checks if the response has a domain error.

## Examples

    iex> response = Anubis.MCP.Response.from_json_rpc(%{"result" => %{"data" => "value"}, "id" => "req_123"})
    iex> Anubis.MCP.Response.error?(response)
    false
    
    iex> error_response = Anubis.MCP.Response.from_json_rpc(%{"result" => %{"isError" => true}, "id" => "req_123"})
    iex> Anubis.MCP.Response.error?(error_response)
    true

## get_result/1

Gets the result data from the response.

This function returns the raw result regardless of whether it represents
a success or domain error.

## Examples

    iex> response = Anubis.MCP.Response.from_json_rpc(%{"result" => %{"data" => "value"}, "id" => "req_123"})
    iex> Anubis.MCP.Response.get_result(response)
    %{"data" => "value"}

## get_id/1

Gets the request ID associated with this response.

## Examples

    iex> response = Anubis.MCP.Response.from_json_rpc(%{"result" => %{}, "id" => "req_123"})
    iex> Anubis.MCP.Response.get_id(response)
    "req_123"