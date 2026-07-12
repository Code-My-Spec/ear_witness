# Anubis.Server.TaskStore.Local

In-memory `Anubis.Server.TaskStore` adapter backed by a single GenServer.

Holds a `%{session_id => %{task_id => Task.t()}}` map. Suitable for STDIO
transports and most HTTP deployments running on a single node. Tasks are lost
on process restart — that's an accepted Phase 1 limitation; persistent
storage will arrive via a future adapter.

## start_link/1

Starts the local task store.

## Options

  * `:name` — registered process name (required)