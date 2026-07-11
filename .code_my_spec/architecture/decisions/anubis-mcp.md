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
Use Anubis (`{:anubis_mcp, "~> 1.6"}`), mounting its Phoenix transport on
the local endpoint (127.0.0.1:4848) so MCP clients on the same machine —
Claude Code, Claude Desktop, anything MCP-capable — can call EarWitness
tools. Local-only binding preserves the local-first-privacy ADR: nothing is
exposed off-machine.

## Consequences
- Tool modules follow Anubis's component pattern; QA needs an SSE-aware MCP
  client (plain one-shot curl gets `202 Accepted`).
- The MCP surface shares the app's lifecycle — tools are only available
  while the desktop app runs.
