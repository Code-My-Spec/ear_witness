# Anubis.Server.TaskStore

Behaviour for pluggable MCP task storage backends.

A TaskStore tracks `Anubis.Server.Task` entries scoped to a session.
Adapters are wired via the `:task_store` option of `Anubis.Server.Supervisor`
using the same `{module, opts}` shape as `:registry` and `:supervisor`:

    {Anubis.Server, transport: :stdio, task_store: {MyApp.HordeTaskStore, []}}

Phase 1 ships with the in-memory `Anubis.Server.TaskStore.Local` adapter.
Distributed adapters (e.g. Horde-backed) plug in through this contract
without API changes.

## Naming

Adapters can either be named processes (default — server boots them under its
supervision tree using `Anubis.Server.Registry.task_store_name/1`) or expose
a custom name (`:via` tuple, registered atom in another node, etc.) via the
optional `resolve_name/2` callback.

When `resolve_name/2` is implemented and returns a `:via` tuple, the adapter
is responsible for its own registration — the server supervisor will skip the
default child spec via `child_spec/1` returning `:ignore`.

## resolve_name/3

Resolves the configured task store name for a server, asking the adapter if
it implements `resolve_name/2` and falling back to the default atom naming.

Uses `Code.ensure_loaded?/1` first because in releases the adapter beam may
exist on disk but not yet be loaded into the VM, in which case
`function_exported?/3` silently returns false and we'd skip the override.