# Anubis.Protocol.Behaviour

Behaviour that each MCP protocol version module must implement.

Each protocol version (e.g., 2024-11-05, 2025-03-26, 2025-06-18) implements
this behaviour to isolate version-specific logic. This makes it trivial to add
support for new MCP spec versions without scattering conditionals across the codebase.

## Version differences

- **2024-11-05**: Initial spec, SSE transport, basic tools/resources/prompts
- **2025-03-26**: Added Streamable HTTP, JSON-RPC batching, authorization framework, tool annotations
- **2025-06-18**: Removed batching, added structured tool output, elicitation, resource_link type