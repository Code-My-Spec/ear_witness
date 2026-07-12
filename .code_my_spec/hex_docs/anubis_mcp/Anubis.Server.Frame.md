# Anubis.Server.Frame

The Anubis Frame — pure user state + read-only context.

## User fields

  * `assigns` - shared user data as a map. For HTTP transports, this inherits
    from `Plug.Conn.assigns`.

## Component maps

Runtime-registered components are stored in typed maps keyed by name/URI:

  * `tools` - `%{name => %Tool{}}`
  * `resources` - `%{uri => %Resource{}}`
  * `prompts` - `%{name => %Prompt{}}`
  * `resource_templates` - `%{name => %Resource{uri_template: ...}}`

## Pagination

  * `pagination_limit` - optional limit for listing operations

## Context

  * `context` - read-only `%Context{}`, refreshed by Session before each callback

## new/1

Creates a new frame with optional initial assigns.

## Examples

    iex> Frame.new()
    %Frame{assigns: %{}}

    iex> Frame.new(%{user: "alice"})
    %Frame{assigns: %{user: "alice"}}

## assign/2

Assigns a value or multiple values to the frame.

## Examples

    frame = Frame.assign(frame, :status, :active)
    frame = Frame.assign(frame, %{status: :active, count: 5})
    frame = Frame.assign(frame, status: :active, count: 5)

## assign_new/3

Assigns a value to the frame only if the key doesn't already exist.

The value is computed lazily using the provided function.

## Examples

    frame = Frame.assign_new(frame, :timestamp, fn -> DateTime.utc_now() end)

## put_pagination_limit/2

Sets the pagination limit for listing operations.

## Examples

    frame = Frame.put_pagination_limit(frame, 10)
    frame.pagination_limit
    # => 10

## register_tool/3

Registers a tool definition at runtime.

## register_prompt/3

Registers a prompt definition at runtime.

## register_resource/3

Registers a resource definition with a fixed URI.

For parameterized resources, use `register_resource_template/3` instead.

## register_resource_template/3

Registers a resource template definition using a URI template (RFC 6570).

## Examples

    frame = Frame.register_resource_template(frame, "file:///{path}",
      name: "project_files",
      title: "Project Files",
      description: "Access files in the project directory"
    )

## subscribe_resource/2

Records that this session has subscribed to updates for the given resource
URI.

Idempotent — subscribing twice to the same URI is a no-op. Per the MCP spec,
the URI does not need to refer to a currently-registered resource.

## unsubscribe_resource/2

Removes a previously-recorded subscription for the given URI.

## resource_subscribed?/2

Returns whether this session has an active subscription for the given URI.

## clear_components/1

Clears all runtime-registered components

## get_components/1

Retrieves all runtime-registered components as a flat list

## authorization/1

Returns the OAuth 2.1 claims from the current request context, or `nil` if
no authorization is configured or the transport is STDIO.

## Examples

    case Frame.authorization(frame) do
      nil -> # no auth configured
      claims -> claims.sub
    end

## subject/1

Returns the `sub` (subject) claim from the bearer token, or `nil`.

## Examples

    Frame.subject(frame)
    # => "user-id-123"

## scopes/1

Returns the list of granted scopes from the bearer token.

Returns an empty list when no authorization is present.

## Examples

    Frame.scopes(frame)
    # => ["tools:read", "tools:write"]

## has_scope?/2

Returns `true` if the bearer token grants the given scope.

## Examples

    Frame.has_scope?(frame, "tools:read")
    # => true

## has_all_scopes?/2

Returns `true` if the bearer token grants **all** of the given scopes.

## Examples

    Frame.has_all_scopes?(frame, ["tools:read", "tools:write"])
    # => true

## authenticated?/1

Returns `true` if the request carries validated OAuth 2.1 claims.

## Examples

    Frame.authenticated?(frame)
    # => true

## to_saved/1

Serializes Frame for persistent storage.

Only `assigns` and `pagination_limit` are persisted. The following fields are
**runtime-only** and excluded from serialization:

  * `tools` — runtime-registered tool definitions (includes validator functions)
  * `resources` — runtime-registered resource definitions
  * `prompts` — runtime-registered prompt definitions
  * `resource_templates` — runtime-registered resource template definitions
  * `context` — rebuilt by Session before each callback invocation

Compile-time components (registered via the `component` macro) are always
available from the server module and do not need persistence.

## from_saved/1

Reconstructs Frame from a previously saved map.

Restored: `assigns`, `pagination_limit`, `resource_subscriptions`. Runtime-only fields
(`tools`, `resources`, `prompts`, `resource_templates`) are initialized empty — their
validator functions are not serializable. `context` is left as the default struct and
will be set by Session before each callback invocation.