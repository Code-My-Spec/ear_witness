# Anubis.Server.Task

Represents an MCP task — a durable state machine wrapping a long-running request.

Spec reference: <https://modelcontextprotocol.io/specification/2025-11-25/basic/utilities/tasks>.

Tasks are receiver-owned: when a server accepts a task-augmented request (e.g.
`tools/call` with a `task` field), it generates a task id, runs the work
asynchronously, and exposes the lifecycle through the `tasks/get`,
`tasks/result`, and `tasks/cancel` operations.

## generate_id/0

Generates a cryptographically-strong task id.

Per spec: receivers MUST use enough entropy to prevent guessing when no
authorization context is bound to the task.

## new/1

Builds a fresh task in `:working` status.

## terminal?/1

Returns true when the task is in a terminal status.

## transition/3

Transitions the task into a new status. The caller is responsible for
enforcing the FSM (`working ↔ input_required → terminal`).

## to_protocol/1

Builds the wire-format `Task` projection used by `tasks/*` responses and the
`notifications/tasks/status` notification. Excludes the underlying result.

## to_create_result/1

Wraps the task projection inside the `CreateTaskResult` envelope returned to
the requestor at task creation time.