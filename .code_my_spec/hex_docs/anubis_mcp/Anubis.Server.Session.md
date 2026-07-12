# Anubis.Server.Session

Per-client MCP session process.

Each Session is a GenServer that manages the lifecycle of a single MCP client
connection. It handles protocol initialization, request/notification dispatch,
server-initiated requests (sampling, roots), and session persistence.

Sessions are created by the transport layer (STDIO creates one at startup,
HTTP transports create them dynamically via `Anubis.Server.Supervisor`).

## start_link/1

Starts a Session process linked to the current process.

## Options

  * `:session_id` — unique session identifier (required)
  * `:server_module` — the MCP server module implementing `Anubis.Server` (required)
  * `:name` — GenServer registration name (required)
  * `:transport` — transport configuration `[layer: module, name: name]` (required)
  * `:task_supervisor` — name of the `Task.Supervisor` for async work (required)
  * `:registry` — session registry module (default: `Anubis.Server.Registry`)
  * `:session_idle_timeout` — idle timeout in ms before session expires (default: 30 min)
  * `:timeout` — request timeout in ms (default: 30s)

## auto_initialize/1

Auto-initializes a session without a client initialize handshake.

This is used when a client sends a non-initialize request to an expired or
unknown session. Instead of returning 404, the server can create a new session
and auto-initialize it so the request can be processed transparently.

Uses the server's latest supported protocol version and synthetic client info
(`%{"name" => "auto-recovered", "version" => "unknown"}`). Server implementations
should not rely on this identity for client-specific decisions.