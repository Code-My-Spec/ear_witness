# Anubis.Protocol.V2025_11_25

Protocol implementation for MCP specification version 2025-11-25.

Builds on 2025-06-18, adding:
- Tasks — durable state machines for long-running requests:
  `tasks/get`, `tasks/result`, `tasks/list`, `tasks/cancel`, and the
  `notifications/tasks/status` notification.