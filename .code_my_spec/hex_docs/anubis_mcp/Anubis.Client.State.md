# Anubis.Client.State



## add_progress_token_to_params/2

Helper function to add progress token to params if provided.

## register_progress_callback_from_opts/2

Helper function to register progress callback from options.

## get_request/2

Gets a request by ID.

## Parameters

  * `state` - The current client state
  * `id` - The request ID to retrieve

## Examples

    iex> Anubis.Client.State.get_request(state, "req_123")
    {{pid, ref}, "ping", timer_ref, start_time} # or nil if not found

## remove_request/2

Removes a request and returns its info along with the updated state.

## Parameters

  * `state` - The current client state
  * `id` - The request ID to remove

## Examples

    iex> {request_info, updated_state} = Anubis.Client.State.remove_request(state, "req_123")
    iex> request_info.method
    "ping"
    iex> request_info.elapsed_ms > 0
    true

## handle_request_timeout/2

Handles a request timeout, cancelling the timer and returning the updated state.

## Parameters

  * `state` - The current client state
  * `id` - The request ID that timed out

## Examples

    iex> Anubis.Client.State.handle_request_timeout(state, "req_123")
    {%{from: from, method: "ping", elapsed_ms: 30000}, updated_state}

## register_progress_callback/3

Registers a progress callback for a token.

## Parameters

  * `state` - The current client state
  * `token` - The progress token to register a callback for
  * `callback` - The callback function to call when progress updates are received

## Examples

    iex> updated_state = Anubis.Client.State.register_progress_callback(state, "token123", fn token, progress, total -> IO.inspect({token, progress, total}) end)
    iex> Map.has_key?(updated_state.progress_callbacks, "token123")
    true

## get_progress_callback/2

Gets a progress callback for a token.

## Parameters

  * `state` - The current client state
  * `token` - The progress token to get the callback for

## Examples

    iex> callback = Anubis.Client.State.get_progress_callback(state, "token123")
    iex> is_function(callback, 3)
    true

## unregister_progress_callback/2

Unregisters a progress callback for a token.

## Parameters

  * `state` - The current client state
  * `token` - The progress token to unregister the callback for

## Examples

    iex> updated_state = Anubis.Client.State.unregister_progress_callback(state, "token123")
    iex> Map.has_key?(updated_state.progress_callbacks, "token123")
    false

## set_log_callback/2

Sets the log callback.

## Parameters

  * `state` - The current client state
  * `callback` - The callback function to call when log messages are received

## Examples

    iex> updated_state = Anubis.Client.State.set_log_callback(state, fn level, data, logger -> IO.inspect({level, data, logger}) end)
    iex> is_function(updated_state.log_callback, 3)
    true

## clear_log_callback/1

Clears the log callback.

## Parameters

  * `state` - The current client state

## Examples

    iex> updated_state = Anubis.Client.State.clear_log_callback(state)
    iex> is_nil(updated_state.log_callback)
    true

## get_log_callback/1

Gets the log callback.

## Parameters

  * `state` - The current client state

## Examples

    iex> callback = Anubis.Client.State.get_log_callback(state)
    iex> is_function(callback, 3) or is_nil(callback)
    true

## update_server_info/3

Updates server info and capabilities after initialization.

## Parameters

  * `state` - The current client state
  * `server_capabilities` - The server capabilities received from initialization
  * `server_info` - The server information received from initialization

## Examples

    iex> updated_state = Anubis.Client.State.update_server_info(state, %{"resources" => %{}}, %{"name" => "TestServer"})
    iex> updated_state.server_capabilities
    %{"resources" => %{}}
    iex> updated_state.server_info
    %{"name" => "TestServer"}

## list_pending_requests/1

Returns a list of all pending requests.

## Parameters

  * `state` - The current client state

## Examples

    iex> requests = Anubis.Client.State.list_pending_requests(state)
    iex> length(requests) > 0
    true
    iex> hd(requests).method
    "ping"

## get_server_capabilities/1

Gets the server capabilities.

## Parameters

  * `state` - The current client state

## Examples

    iex> Anubis.Client.State.get_server_capabilities(state)
    %{"resources" => %{}, "tools" => %{}}

## get_server_info/1

Gets the server info.

## Parameters

  * `state` - The current client state

## Examples

    iex> Anubis.Client.State.get_server_info(state)
    %{"name" => "TestServer", "version" => "1.0.0"}

## merge_capabilities/2

Merges additional capabilities into the client's capabilities.

## Parameters

  * `state` - The current client state
  * `additional_capabilities` - The capabilities to merge

## Examples

    iex> updated_state = Anubis.Client.State.merge_capabilities(state, %{"tools" => %{"execute" => true}})
    iex> updated_state.capabilities["tools"]["execute"]
    true

## validate_capability/2

Validates if a method is supported by the server's capabilities.

## Parameters

  * `state` - The current client state
  * `method` - The method to validate

## Returns

  * `:ok` if the method is supported
  * `{:error, %Anubis.MCP.Error{}}` if the method is not supported

## Examples

    iex> Anubis.Client.State.validate_capability(state_with_resources, "resources/list")
    :ok
    
    iex> {:error, error} = Anubis.Client.State.validate_capability(state_without_tools, "tools/list")
    iex> error.reason
    :method_not_found

## add_root/3

Adds a root directory to the state.

## Parameters

  * `state` - The current client state
  * `uri` - The URI of the root directory (must start with "file://")
  * `name` - Optional human-readable name for display purposes

## Examples

    iex> updated_state = Anubis.Client.State.add_root(state, "file:///home/user/project", "My Project")
    iex> updated_state.roots
    [%{uri: "file:///home/user/project", name: "My Project"}]

## remove_root/2

Removes a root directory from the state.

## Parameters

  * `state` - The current client state
  * `uri` - The URI of the root directory to remove

## Examples

    iex> updated_state = Anubis.Client.State.remove_root(state, "file:///home/user/project")
    iex> updated_state.roots
    []

## get_root_by_uri/2

Gets a root directory by its URI.

## Parameters

  * `state` - The current client state
  * `uri` - The URI of the root directory to get

## Examples

    iex> Anubis.Client.State.get_root_by_uri(state, "file:///home/user/project")
    %{uri: "file:///home/user/project", name: "My Project"}

## list_roots/1

Lists all root directories.

## Parameters

  * `state` - The current client state

## Examples

    iex> Anubis.Client.State.list_roots(state)
    [%{uri: "file:///home/user/project", name: "My Project"}]

## clear_roots/1

Clears all root directories.

## Parameters

  * `state` - The current client state

## Examples

    iex> updated_state = Anubis.Client.State.clear_roots(state)
    iex> updated_state.roots
    []

## set_sampling_callback/2

Sets the sampling callback function.

## Parameters

  * `state` - The current client state
  * `callback` - The callback function to handle sampling requests

## Examples

    iex> callback = fn params -> {:ok, %{role: "assistant", content: %{type: "text", text: "Hello"}}} end
    iex> updated_state = Anubis.Client.State.set_sampling_callback(state, callback)
    iex> is_function(updated_state.sampling_callback, 1)
    true

## get_sampling_callback/1

Gets the sampling callback function.

## Parameters

  * `state` - The current client state

## Examples

    iex> Anubis.Client.State.get_sampling_callback(state)
    nil

## clear_sampling_callback/1

Clears the sampling callback function.

## Parameters

  * `state` - The current client state

## Examples

    iex> updated_state = Anubis.Client.State.clear_sampling_callback(state)
    iex> updated_state.sampling_callback
    nil

## set_elicitation_callback/2

Sets the elicitation callback function.

Callback receives `(message, requested_schema)` and returns one of
`{:accept, content}`, `:decline`, `:cancel`, or `{:error, reason}`.

## get_elicitation_callback/1

Gets the elicitation callback function.

## clear_elicitation_callback/1

Clears the elicitation callback function.