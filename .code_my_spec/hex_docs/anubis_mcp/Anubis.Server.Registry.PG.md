# Anubis.Server.Registry.PG

Distributed session registry backed by Erlang's `:pg` (process groups) module.

Uses a named `:pg` scope to track session PIDs across all nodes in an Erlang
cluster, enabling transparent cross-node request routing for horizontally
scaled MCP server deployments.

## When to use this registry

The default `Anubis.Server.Registry.Local` stores session PIDs in a node-local
ETS table. In a multi-node deployment without sticky sessions this causes
failures:

1. An `initialize` request hits node A — session process starts there.
2. The `notifications/initialized` notification hits node B — no local session
   found, 404 returned, notification lost.
3. A subsequent `tools/call` back to node A finds the live session with
   `initialized: false` → `"Server not initialized"` error.

`Registry.PG` solves this by tracking session PIDs in a `:pg` scope that is
shared across all connected Erlang nodes. When node B receives any request for
a session that lives on node A:

1. `lookup_session/2` queries `:pg` and returns node A's session PID.
2. `GenServer.call/3` routes the request to node A transparently via
   distributed Erlang — no serialisation, no HTTP hop.
3. The session on node A handles the request in its correct state.

`:pg` monitors registered processes and removes their entries automatically
when a process exits, so stale PIDs are never returned.

## Requirements

- OTP 23+ (`:pg` was introduced in OTP 23 as a replacement for `:pg2`).
- All MCP server nodes must be connected via distributed Erlang. If you are
  not already managing node clustering yourself, libraries such as
  [libcluster](https://github.com/bitwalker/libcluster) can handle automatic
  cluster formation for a variety of strategies including Kubernetes DNS,
  Consul, and gossip protocols.

## Usage

    children = [
      {MyServer, transport: {:streamable_http, start: true}, registry: {Anubis.Server.Registry.PG, []}}
    ]

## Pairing with a session store

`Registry.PG` routes requests to live session processes across the cluster.
It does **not** persist sessions across node restarts. To survive node crashes
or rolling deployments, pair this registry with an
`Anubis.Server.Session.Store` implementation (e.g. Redis or a database) so
that sessions can be restored on any node after a restart.