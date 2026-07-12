# Anubis.Server

Build MCP servers that extend language model capabilities.

MCP servers are specialized processes that provide three core primitives to AI assistants:
**Resources** (contextual data like files or schemas), **Tools** (actions the model can invoke),
and **Prompts** (user-selectable templates). They operate in a secure, isolated architecture
where clients maintain 1:1 connections with servers, enabling composable functionality while
maintaining strict security boundaries.

## Quick Start

Create a server in three steps:

    defmodule MyServer do
      use Anubis.Server,
        name: "my-server",
        version: "1.0.0",
        capabilities: [:tools]

      component MyServer.Calculator
    end

    defmodule MyServer.Calculator do
      @moduledoc "Add two numbers"

      use Anubis.Server.Component, type: :tool

      schema do
        field :a, :number, required: true
        field :b, :number, required: true
      end

      def execute(%{a: a, b: b}, _frame) do
        {:ok, a + b}
      end
    end

    # In your supervision tree
    children = [{MyServer, transport: :stdio}]
    Supervisor.start_link(children, strategy: :one_for_one)

Your server is now a living process that AI assistants can connect to, discover available
tools, and execute calculations through a secure protocol boundary.

## Capabilities

Declare what your server can do:

- **`:tools`** - Execute functions with structured inputs and outputs
- **`:resources`** - Provide data that models can read (files, APIs, databases)
- **`:prompts`** - Offer reusable templates for common interactions
- **`:logging`** - Allow clients to configure verbosity levels

Configure capabilities with options:

    use Anubis.Server,
      capabilities: [
        :tools,
        {:resources, subscribe?: true},      # Enable resource update subscriptions
        {:prompts, list_changed?: true}      # Notify when prompts change
      ]

## Components

Register tools, resources, and prompts as components:

    component MyServer.FileReader           # Auto-named as "file_reader"
    component MyServer.ApiClient, name: "api"   # Custom name

Components are modules that implement specific behaviors
and are automatically discovered by clients through the protocol.

## Server Lifecycle

Your server follows a predictable lifecycle with callbacks you can hook into:

1. **`init/2`** - Set up initial state when the server starts
2. **`handle_request/2`** - Process MCP protocol requests from clients
3. **`handle_notification/2`** - React to one-way client messages
4. **`handle_info/2`** - Bridge external events into MCP notifications

Most protocol handling is automatic - you typically only implement `init/2` for setup
and occasionally override other callbacks for custom behavior.

## Sending Notifications

Notification functions use `send(self(), ...)` and must be called from within the
Session process (i.e., inside callbacks). For sending from external processes or tasks,
use `send/2` with the session PID directly.

    # Inside a callback:
    def handle_info(:data_changed, frame) do
      Anubis.Server.send_tools_list_changed()
      {:noreply, frame}
    end

## __using__/1

Called when a session is being auto-recovered after expiry.

Invoked during `auto_initialize/1` instead of the normal client handshake.
Receives the session ID and the current frame (pre-populated from the session
store if one is configured).

Return values:
- `{:ok, frame}` — accept recovery using synthetic client info
- `{:ok, client_info, frame}` — accept recovery and supply real client info
- `{:error, reason}` — reject recovery; the client receives an internal error

If this callback is not implemented, the default behavior is unchanged:
synthetic client info is used and `init/2` is called normally.

## component/2

Registers a component (tool, prompt, or resource) with the server.

## send_resources_list_changed/0

Sends a resources list changed notification.

**Must be called from within a Session callback** — the current process must be
the Session GenServer. Calling from outside a callback will silently lose the message.

For external processes, use `send(session_pid, {:send_notification, "notifications/resources/list_changed", %{}})`.

## send_resource_updated/2

Sends a resource updated notification for a specific resource.

Subscription-gated: only emits if the current session has previously
received a `resources/subscribe` request for this URI. Calls for
unsubscribed URIs are silently dropped.

**Must be called from within a Session callback** — see `send_resources_list_changed/0` for details.

## send_prompts_list_changed/0

Sends a prompts list changed notification.

**Must be called from within a Session callback** — see `send_resources_list_changed/0` for details.

## send_tools_list_changed/0

Sends a tools list changed notification.

**Must be called from within a Session callback** — see `send_resources_list_changed/0` for details.

## send_log_message/3

Sends a log message to the client.

**Must be called from within a Session callback** — see `send_resources_list_changed/0` for details.

## send_progress/3

Sends a progress notification for an ongoing operation.

## send_task_status/1

Sends a `notifications/tasks/status` notification with the current state of
the given task.

**Must be called from within a Session callback** — see
`send_resources_list_changed/0` for details.

Per spec (2025-11-25), receivers MAY send these notifications when a task's
status changes; they are optional and requestors MUST NOT rely on them. This
helper looks up the task in the configured task store and emits the full
`Task` projection.

## send_sampling_request/2

Sends a sampling/createMessage request to the client.

This is an asynchronous operation. The response will be delivered to your
`handle_sampling/3` callback.

## send_roots_request/1

Sends a roots/list request to the client.

## send_elicitation_request/3

Sends an `elicitation/create` request to the client.

Per the MCP 2025-06-18 specification, the server provides a human-readable
`message` and a restricted-subset JSON `requested_schema` describing the
expected user input. The client presents this to the user and returns one of
three actions: `accept` (with content matching the schema), `decline`, or
`cancel`.

This is an asynchronous operation. The response will be delivered to your
`handle_elicitation/3` callback.

The `requested_schema` is validated synchronously before any wire I/O. The
client must advertise the `elicitation` capability or the call returns
`{:error, :capability_not_supported}` after enqueueing.

## Schema Subset

  * Top level must be `%{"type" => "object", "properties" => %{...}}`
  * Properties may declare `"type"` of `"string"`, `"number"`, `"integer"`,
    `"boolean"`, or use `"enum"` (string-only)
  * String properties may set `"format"` of `"email"`, `"uri"`, `"date"`,
    or `"date-time"`

Per the spec, **servers MUST NOT request sensitive information** through
elicitation.

## Example

    defmodule MyServer.Tools.Greet do
      use Anubis.Server.Component, type: :tool

      @impl true
      def execute(_args, frame) do
        Anubis.Server.send_elicitation_request("What's your name?", %{
          "type" => "object",
          "properties" => %{
            "name" => %{"type" => "string", "minLength" => 1}
          },
          "required" => ["name"]
        })

        {:reply, "asked for name", frame}
      end
    end