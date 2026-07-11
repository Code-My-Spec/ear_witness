# Use Anubis for the local MCP server

## Status
Accepted

## Context
Story 868 exposes the conversation library to AI assistants via MCP tools
(`EarWitnessWeb.McpServer` in the architecture). We need an Elixir MCP
server implementation that integrates with the existing Phoenix endpoint
and runs entirely locally.

## Options Considered
- **Anubis (`anubis_mcp`)** — MCP implementation in Elixir with Phoenix
  integration (Streamable HTTP transport); the same library CodeMySpec's own
  server is built on, so the team already knows its component model
  (`use Anubis.Server.Component, type: :tool`) and its quirks (SSE responses,
  `mcp-session-id` handshake).
- **Hand-rolled JSON-RPC over Plug** — no dependency, but reimplements
  session management, tool schemas, and transports the library already does.

## Decision
Use Anubis (`{:anubis_mcp, "~> 1.6"}`) over its **stdio transport** (PM
decision 2026-07-11, story 868): MCP clients — Claude Code, Claude Desktop,
anything MCP-capable — launch/connect to an EarWitness stdio endpoint on the
same machine. No network port is opened for assistant access, which makes
the local-first-privacy guarantee structural rather than configured. Scope:
read tools (search, transcripts with speakers/timestamps) plus a single
write tool (attach summary/note to a recording); access is user-enabled and
revocable.

## Consequences
- Tool modules follow Anubis's component pattern.
- QA drives the tool modules directly (or via an MCP client) — there is no
  HTTP transport to curl.
- The stdio entry point must reach the running app's data (or boot enough of
  it) — the launcher design lands with the McpServer surface spec.
