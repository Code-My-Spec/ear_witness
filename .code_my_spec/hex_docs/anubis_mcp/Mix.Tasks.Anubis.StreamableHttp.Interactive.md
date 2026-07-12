# Mix.Tasks.Anubis.StreamableHttp.Interactive

Mix task to test the Streamable HTTP transport implementation, interactively sending commands.

## Options

* `--base-url` - Base URL for the MCP server (default: http://localhost:8000)
* `--mcp-path` - MCP endpoint path (default: /mcp)
* `--header` - Add a header to requests (can be specified multiple times)

## Examples

    mix anubis.streamable_http.interactive --base-url http://localhost:8000
    mix anubis.streamable_http.interactive --header "Authorization: Bearer token123"
    mix anubis.streamable_http.interactive --header "X-API-Key: secret" --header "X-Custom: value"