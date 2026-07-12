# Anubis.Server.ConfigurationError

Raised when required MCP server configuration is missing or invalid.

The MCP specification requires servers to provide:
- `name`: A human-readable name for the server
- `version`: The server's version string

## Examples

    # This will raise an error - missing required options
    defmodule BadServer do
      use Anubis.Server  # Raises Anubis.Server.ConfigurationError
    end
    
    # This is correct
    defmodule GoodServer do
      use Anubis.Server,
        name: "My Server",
        version: "1.0.0"
    end