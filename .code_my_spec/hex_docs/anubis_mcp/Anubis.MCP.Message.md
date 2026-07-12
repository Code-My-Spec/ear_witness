# Anubis.MCP.Message

Handles parsing and validation of MCP (Model Context Protocol) messages using the Peri library.

This module provides functions to parse and validate MCP messages based on the Model Context Protocol schema

## decode/1

Decodes raw data (possibly containing multiple messages) into JSON-RPC messages.

Returns either:
- `{:ok, messages}` where messages is a list of parsed JSON-RPC messages
- `{:error, reason}` if parsing fails

## validate_message/1

Validates a decoded JSON message to ensure it complies with the MCP schema.

## encode_request/2

Encodes a request message to a JSON-RPC 2.0 compliant string.

Returns the encoded string with a newline character appended.

## encode_request/3

Encodes a request message using a custom schema.

## Parameters

  * `request` - The request map containing method and params
  * `id` - The request ID
  * `schema` - The Peri schema to use for validation

Returns the encoded string with a newline character appended.

## encode_notification/1

Encodes a notification message to a JSON-RPC 2.0 compliant string.

Returns the encoded string with a newline character appended.

## encode_notification/2

Encodes a notification message using a custom schema.

## Parameters

  * `notification` - The notification map containing method and params
  * `schema` - The Peri schema to use for validation

Returns the encoded string with a newline character appended.

## encode_progress_notification/2

Encodes a progress notification message to a JSON-RPC 2.0 compliant string.

## Parameters

  * `params` - Map containing progress parameters:
    * `"progressToken"` - The token that was provided in the original request (string or integer)
    * `"progress"` - The current progress value (number)
    * `"total"` - Optional total value for the operation (number)
    * `"message"` - Optional descriptive message (string, for 2025-03-26)
  * `params_schema` - Optional Peri schema for params validation (defaults to @progress_notif_params_schema)

Returns the encoded string with a newline character appended.

## encode_progress_notification/3

Legacy function for progress notifications with individual parameters.

**Deprecated**: Prefer using `encode_progress_notification/2` with a params map.

This function will be removed in a future release. Update your code to use the newer function:

    encode_progress_notification(%{
      "progressToken" => progress_token,
      "progress" => progress,
      "total" => total
    })

## encode_response/2

Encodes a response message to a JSON-RPC 2.0 compliant string.

Returns the encoded string with a newline character appended.

## encode_response/3

Encodes a response message using a custom schema.

## Parameters

  * `response` - The response map containing result
  * `id` - The response ID
  * `schema` - The Peri schema to use for validation

Returns the encoded string with a newline character appended.

## encode_error/2

Encodes an error message to a JSON-RPC 2.0 compliant string.

Returns the encoded string with a newline character appended.

## encode_log_message/3

Encodes a log message notification to be sent to the client.

## Parameters

  * `level` - The log level (debug, info, notice, warning, error, critical, alert, emergency)
  * `data` - The data to be logged (any JSON-serializable value)
  * `logger` - Optional name of the logger issuing the message

Returns the encoded notification string with a newline character appended.

## progress_params_schema_2025/0

Returns the progress notification parameters schema for 2025-03-26 (with message field).

## progress_params_schema/0

Returns the standard progress notification parameters schema for 2024-11-05.

## progress_params_schema_for/1

Returns the progress notification parameters schema for a given protocol version.

Delegates to the version module via `Anubis.Protocol.Registry`.

## Examples

    iex> Message.progress_params_schema_for("2024-11-05")
    %{"progressToken" => {:required, {:either, {:string, :integer}}}, ...}

    iex> Message.progress_params_schema_for("2025-03-26")
    %{"progressToken" => ..., "message" => :string}

## build_response/2

Builds a response message map without encoding to JSON.

## Examples

    iex> Message.build_response(%{"value" => 42}, "req_123")
    %{"jsonrpc" => "2.0", "result" => %{"value" => 42}, "id" => "req_123"}

## build_error/2

Builds an error message map without encoding to JSON.

## Examples

    iex> Message.build_error(%{"code" => -32600, "message" => "Invalid Request"}, "req_123")
    %{"jsonrpc" => "2.0", "error" => %{"code" => -32600, "message" => "Invalid Request"}, "id" => "req_123"}

## build_notification/2

Builds a notification message map without encoding to JSON.

## Examples

    iex> Message.build_notification("notifications/message", %{"level" => "info", "data" => "test"})
    %{"jsonrpc" => "2.0", "method" => "notifications/message", "params" => %{"level" => "info", "data" => "test"}}