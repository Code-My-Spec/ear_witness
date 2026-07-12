# Anubis.Client

MCP (Model Context Protocol) client for connecting to MCP servers.

This module provides a fully functional MCP client with automatic supervision,
transport management, and all standard MCP operations. No macros needed — just
add it to your supervision tree with the desired configuration.

## Usage

Add the client to your supervision tree:

    children = [
      {Anubis.Client,
       name: MyApp.MCPClient,
       transport: {:stdio, command: "uvx", args: ["mcp-server-anthropic"]},
       client_info: %{"name" => "MyApp", "version" => "1.0.0"},
       capabilities: %{"roots" => %{}},
       protocol_version: "2025-06-18"}
    ]

Use the client by passing the registered name:

    {:ok, tools} = Anubis.Client.list_tools(MyApp.MCPClient)
    {:ok, result} = Anubis.Client.call_tool(MyApp.MCPClient, "search", %{query: "elixir"})

## Capabilities

Capabilities are passed as a map with string keys:

    %{"roots" => %{}, "sampling" => %{}}

For convenience, use `parse_capability/2` to build from atoms:

    capabilities =
      [:roots, {:sampling, list_changed?: true}]
      |> Enum.reduce(%{}, &Anubis.Client.parse_capability/2)

## Transport Configuration

When starting the client, provide transport configuration:

  * `{:stdio, command: "cmd", args: ["arg1", "arg2"]}`
  * `{:sse, base_url: "http://localhost:8000"}`
  * `{:websocket, url: "ws://localhost:8000/ws"}`
  * `{:streamable_http, url: "http://localhost:8000/mcp"}`

## Process Naming

The `:name` option controls process registration. You can use any valid
`GenServer.name()` — an atom, a PID, or a `{:via, module, term}` tuple:

    # Atom name
    {Anubis.Client, name: MyApp.MCPClient, transport: ...}

    # For distributed systems with registries (e.g., Horde)
    {Anubis.Client,
     name: {:via, Horde.Registry, {MyCluster, "client_1"}},
     transport_name: {:via, Horde.Registry, {MyCluster, "transport_1"}},
     transport: ...}

When using via tuples or other non-atom names, you must explicitly provide
the `:transport_name` option. For atom names, the transport is automatically
named as `Module.concat(ClientName, "Transport")`.

## Dynamic Client Management

For applications that need to manage multiple client connections dynamically
(e.g., user-configured MCP servers), use a `DynamicSupervisor`:

    DynamicSupervisor.start_child(
      MyApp.DynamicSupervisor,
      {Anubis.Client,
       name: {:via, Registry, {MyApp.Registry, client_id}},
       transport_name: {:via, Registry, {MyApp.Registry, {client_id, :transport}}},
       transport: {:streamable_http, base_url: url},
       client_info: %{"name" => "MyApp", "version" => "1.0.0"},
       capabilities: %{},
       protocol_version: "2025-06-18"}
    )

## parse_capability/2

Converts a capability atom or tuple into a map entry.

Useful for building capability maps from ergonomic shorthand:

    capabilities =
      [:roots, {:sampling, list_changed?: true}]
      |> Enum.reduce(%{}, &Anubis.Client.parse_capability/2)
    # => %{"roots" => %{}, "sampling" => %{}}

## child_spec/1

Returns a child specification for starting the client under a supervisor.

This starts a supervision tree containing both the client GenServer and
the configured transport process, linked with a `:one_for_all` strategy.

## start_link/1

Starts the client supervision tree (client + transport).

This is the primary entry point for starting a client. It creates a supervisor
that manages both the client GenServer and the transport process.

## ping/2

Sends a ping request to the server to check connection health. Returns `:pong` if successful.

## Options

  * `:timeout` - Request timeout in milliseconds (default: 30s)
  * `:progress` - Progress tracking options
    * `:token` - A unique token to track progress (string or integer)
    * `:callback` - A function to call when progress updates are received

## list_resources/2

Lists available resources from the server.

## Options

  * `:cursor` - Pagination cursor for continuing a previous request
  * `:timeout` - Request timeout in milliseconds
  * `:progress` - Progress tracking options
    * `:token` - A unique token to track progress (string or integer)
    * `:callback` - A function to call when progress updates are received

## list_resource_templates/2

Lists available resource templates from the server.

## Options

  * `:cursor` - Pagination cursor for continuing a previous request
  * `:timeout` - Request timeout in milliseconds
  * `:progress` - Progress tracking options
    * `:token` - A unique token to track progress (string or integer)
    * `:callback` - A function to call when progress updates are received

## read_resource/3

Reads a specific resource from the server.

## Options

  * `:timeout` - Request timeout in milliseconds
  * `:progress` - Progress tracking options
    * `:token` - A unique token to track progress (string or integer)
    * `:callback` - A function to call when progress updates are received

## subscribe_resource/3

Subscribes to updates for a specific resource URI.

After a successful subscribe, the server may send `notifications/resources/updated`
notifications for this URI. The server must declare the `resources.subscribe`
capability for this method to succeed.

## Options

  * `:timeout` - Request timeout in milliseconds

## unsubscribe_resource/3

Unsubscribes from updates for a previously-subscribed resource URI.

## Options

  * `:timeout` - Request timeout in milliseconds

## list_prompts/2

Lists available prompts from the server.

## Options

  * `:cursor` - Pagination cursor for continuing a previous request
  * `:timeout` - Request timeout in milliseconds
  * `:progress` - Progress tracking options
    * `:token` - A unique token to track progress (string or integer)
    * `:callback` - A function to call when progress updates are received

## get_prompt/4

Gets a specific prompt from the server.

## Options

  * `:timeout` - Request timeout in milliseconds
  * `:progress` - Progress tracking options
    * `:token` - A unique token to track progress (string or integer)
    * `:callback` - A function to call when progress updates are received

## list_tools/2

Lists available tools from the server.

## Options

  * `:cursor` - Pagination cursor for continuing a previous request
  * `:timeout` - Request timeout in milliseconds
  * `:progress` - Progress tracking options
    * `:token` - A unique token to track progress (string or integer)
    * `:callback` - A function to call when progress updates are received

## call_tool/4

Calls a tool on the server.

## Options

  * `:timeout` - Request timeout in milliseconds
  * `:progress` - Progress tracking options
    * `:token` - A unique token to track progress (string or integer)
    * `:callback` - A function to call when progress updates are received

## merge_capabilities/3

Merges additional capabilities into the client's capabilities.

## get_server_capabilities/2

Gets the server's capabilities as reported during initialization.

Returns `nil` if the client has not been initialized yet.

## get_server_info/2

Gets the server's information as reported during initialization.

Returns `nil` if the client has not been initialized yet.

## await_ready/2

Blocks until the client has completed the MCP initialization handshake.

Returns `:ok` once the server capabilities have been received.
If the server has already been initialized, returns immediately.
Otherwise, the caller is parked until the initialization response arrives
or the GenServer call times out.

## Options

  * `:timeout` - Maximum time to wait in milliseconds (default: 30s)

## Examples

    {:ok, _supervisor} = Anubis.Client.start_link(opts)
    :ok = Anubis.Client.await_ready(MyApp.MCPClient, timeout: 10_000)
    {:ok, tools} = Anubis.Client.list_tools(MyApp.MCPClient)

## set_log_level/2

Sets the minimum log level for the server to send log messages.

## Parameters

  * `client` - The client process
  * `level` - The minimum log level (debug, info, notice, warning, error, critical, alert, emergency)

Returns {:ok, result} if successful, {:error, reason} otherwise.

## complete/4

Requests autocompletion suggestions for prompt arguments or resource URIs.

## Parameters

  * `client` - The client process
  * `ref` - Reference to what is being completed (required)
    * For prompts: `%{"type" => "ref/prompt", "name" => prompt_name}`
    * For resources: `%{"type" => "ref/resource", "uri" => resource_uri}`
  * `argument` - The argument being completed (required)
    * `%{"name" => arg_name, "value" => current_value}`
  * `opts` - Additional options
    * `:timeout` - Request timeout in milliseconds
    * `:progress` - Progress tracking options
      * `:token` - A unique token to track progress (string or integer)
      * `:callback` - A function to call when progress updates are received

## Returns

Returns `{:ok, response}` with completion suggestions if successful, or `{:error, reason}` if an error occurs.

The response result contains a "completion" object with:
* `values` - List of completion suggestions (maximum 100)
* `total` - Optional total number of matching items
* `hasMore` - Boolean indicating if more results are available

## register_log_callback/3

Registers a callback function to be called when log messages are received.

## Parameters

  * `client` - The client process
  * `callback` - A function that takes three arguments: level, data, and logger name

The callback function will be called whenever a log message notification is received.

## unregister_log_callback/2

Unregisters a previously registered log callback.

## Parameters

  * `client` - The client process
  * `callback` - The callback function to unregister

## register_progress_callback/4

Registers a callback function to be called when progress notifications are received
for the specified progress token.

## Parameters

  * `client` - The client process
  * `progress_token` - The progress token to watch for (string or integer)
  * `callback` - A function that takes three arguments: progress_token, progress, and total

The callback function will be called whenever a progress notification with the
matching token is received.

## unregister_progress_callback/3

Unregisters a previously registered progress callback for the specified token.

## Parameters

  * `client` - The client process
  * `progress_token` - The progress token to stop watching (string or integer)

## send_progress/5

Sends a progress notification to the server for a long-running operation.

## Parameters

  * `client` - The client process
  * `progress_token` - The progress token provided in the original request (string or integer)
  * `progress` - The current progress value (number)
  * `total` - The optional total value for the operation (number)

Returns `:ok` if notification was sent successfully, or `{:error, reason}` otherwise.

## cancel_request/4

Cancels an in-progress request.

## Parameters

  * `client` - The client process
  * `request_id` - The ID of the request to cancel
  * `reason` - Optional reason for cancellation

## Returns

  * `:ok` if the cancellation was successful
  * `{:error, reason}` if an error occurred
  * `{:not_found, request_id}` if the request ID was not found

## cancel_all_requests/3

Cancels all pending requests.

## Parameters

  * `client` - The client process
  * `reason` - Optional reason for cancellation (defaults to "client_cancelled")

## Returns

  * `{:ok, requests}` - A list of the Request structs that were cancelled
  * `{:error, reason}` - If an error occurred

## add_root/4

Adds a root directory to the client's roots list.

## Parameters

  * `client` - The client process
  * `uri` - The URI of the root directory (must start with "file://")
  * `name` - Optional human-readable name for the root
  * `opts` - Additional options
    * `:timeout` - Request timeout in milliseconds

## remove_root/3

Removes a root directory from the client's roots list.

## Parameters

  * `client` - The client process
  * `uri` - The URI of the root directory to remove
  * `opts` - Additional options
    * `:timeout` - Request timeout in milliseconds

## list_roots/2

Gets a list of all root directories.

## Parameters

  * `client` - The client process
  * `opts` - Additional options
    * `:timeout` - Request timeout in milliseconds

## clear_roots/2

Clears all root directories.

## Parameters

  * `client` - The client process
  * `opts` - Additional options
    * `:timeout` - Request timeout in milliseconds

## register_sampling_callback/2

Registers a callback function to handle sampling requests from the server.

The callback function will be called when the server sends a `sampling/createMessage` request.
The callback should implement user approval and return the LLM response.

## Callback Function

The callback receives the sampling parameters and must return:
- `{:ok, response_map}` - Where response_map contains:
  - `"role"` - Usually "assistant"
  - `"content"` - Message content (text, image, or audio)
  - `"model"` - The model that was used
  - `"stopReason"` - Why generation stopped (e.g., "endTurn")
- `{:error, reason}` - If the user rejects or an error occurs

## unregister_sampling_callback/1

Unregisters the sampling callback.

## register_elicitation_callback/2

Registers a callback function to handle elicitation requests from the server.

The client must advertise the `elicitation` capability during initialization
for servers to send `elicitation/create` requests.

Per the MCP specification, the client SHOULD present the request to the user
with clear UI, allow them to review and modify their response, and provide
decline/cancel options.

## unregister_elicitation_callback/1

Unregisters the elicitation callback.

## close/1

Closes the client connection and terminates the process.