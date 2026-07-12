# Mix.Tasks.Anubis.Sse.Interactive

Mix task to test the SSE transport implementation, interactively sending commands.

> #### Deprecated {: .warning}
>
> This task uses the deprecated SSE transport. As of MCP specification 2025-03-26,
> the HTTP+SSE transport has been replaced by the Streamable HTTP transport.
>
> For testing new servers, please use `mix anubis.streamable_http.interactive` instead.
> This task is maintained for backward compatibility with servers using the
> 2024-11-05 protocol version.

## Options

* `--base-url` - Base URL for the SSE server (default: http://localhost:8000)
* `--base-path` - Base path to append to the base URL
* `--sse-path` - Specific SSE endpoint path
* `--header` - Add a header to requests (can be specified multiple times)

## Examples

    mix anubis.sse.interactive --base-url http://localhost:8000
    mix anubis.sse.interactive --header "Authorization: Bearer token123"
    mix anubis.sse.interactive --header "X-API-Key: secret" --header "X-Custom: value"