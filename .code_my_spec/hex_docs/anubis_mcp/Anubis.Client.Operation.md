# Anubis.Client.Operation

Represents an operation to be performed by the MCP client.

This struct encapsulates all information about a client API call:
- `method` - The MCP method to call
- `params` - The parameters to send to the server
- `progress_opts` - Progress tracking options (optional)
- `timeout` - The timeout for this specific operation (default: 30 seconds)

## new/1

Creates a new operation struct.

## Parameters

  * `attrs` - Map containing the operation attributes
    * `:method` - The MCP method name (required)
    * `:params` - The parameters to send to the server (required)
    * `:progress_opts` - Progress tracking options (optional)
    * `:timeout` - The timeout for this operation in milliseconds (optional, defaults to 30s)