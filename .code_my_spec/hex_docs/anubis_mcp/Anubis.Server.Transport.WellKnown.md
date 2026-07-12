# Anubis.Server.Transport.WellKnown

Plug that serves the RFC 9728 OAuth Protected Resource metadata document
at `/.well-known/oauth-protected-resource`.

Mount this plug at the root of your MCP server so the discovery endpoint is
reachable even when the SSE or Streamable HTTP plugs are mounted under
sub-paths such as `/sse` or `/mcp`.

## Usage

Within a `Plug.Router`:

    forward "/.well-known/oauth-protected-resource",
      to: Anubis.Server.Transport.WellKnown,
      init_opts: [server: MyApp.MCPServer]

    forward "/sse", to: Anubis.Server.Transport.SSE.Plug,
      init_opts: [server: MyApp.MCPServer, mode: :sse]

Within Phoenix:

    forward "/.well-known/oauth-protected-resource",
      Anubis.Server.Transport.WellKnown,
      server: MyApp.MCPServer

Returns `404 Not Found` when the configured server has no authorization
configured.