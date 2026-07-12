# Anubis.Client.Supervisor



## start_link/1

Starts the client supervisor.

## Arguments

  * `opts` - Supervisor options including:
    * `:name` - Optional custom name for the client process (defaults to `Anubis.Client`)
    * `:transport` - Transport configuration (required)
    * `:transport_name` - Optional custom name for the transport process
    * `:client_info` - Client identification info
    * `:capabilities` - Client capabilities map
    * `:protocol_version` - MCP protocol version

## Examples

    # Simple usage with atom names
    Anubis.Client.Supervisor.start_link(
      name: MyApp.MCPClient,
      transport: {:stdio, command: "mcp", args: ["server"]},
      client_info: %{"name" => "MyApp", "version" => "1.0.0"},
      capabilities: %{"roots" => %{}},
      protocol_version: "2024-11-05"
    )

    # With custom names (e.g., for distributed systems)
    Anubis.Client.Supervisor.start_link(
      name: {:via, Horde.Registry, {MyCluster, "client_1"}},
      transport_name: {:via, Horde.Registry, {MyCluster, "transport_1"}},
      transport: {:stdio, command: "mcp", args: ["server"]},
      client_info: %{"name" => "MyApp", "version" => "1.0.0"},
      capabilities: %{"roots" => %{}},
      protocol_version: "2024-11-05"
    )