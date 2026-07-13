# QA Story 868 Brief — Let my AI assistant work my conversations

## Tool

script (`mix run --no-start`) + web + curl/lsof/router inspection

## Auth

Web (Settings page toggle): navigate once to the login URL printed by
`qa_server.exs` (`http://localhost:4848/?k=<KEY>`), then browse normally.

Script probe (`mix run --no-start`): no auth needed — it starts only
`ecto_sqlite3` + `EarWitness.Repo` directly against the running app's own
DB file (`.config/todo/database.sq3`, cwd-relative), the same pattern as
`priv/repo/qa_seeds.exs`. No endpoint, no window, no port collision.

## Seeds

None needed — the running app's library already has transcribed QA
fixture recordings from prior story QA sessions (`QA862c-*`, `QA863-*`,
etc.). Used recording id 37 ("QA862c-two-person.wav", a mock rental
hearing transcript with 6 segments) as the probe target.

## What To Test

- **Criterion 7377 — Claude Code connects and lists the tools.** Check
  whether an actual external MCP client can launch/attach to
  `EarWitnessWeb.McpServer.Server`: inspect `lib/ear_witness_web/application.ex`
  supervision tree, `mix.exs` for `escript:`/release entrypoints, and the
  repo for any `.mcp.json`/README instructions a real client would use.
- **Criterion 7378 — Ask the assistant what was decided.** Call
  `EarWitnessWeb.McpServer.search_transcripts/1` and `read_transcript/1`
  against real transcript data via a `mix run --no-start` probe script.
- **Criterion 7379 — Assistant saves a meeting summary onto the
  recording.** Call `attach_summary/1` on recording 37, then re-call
  `read_transcript/1` to confirm the summary round-trips through the DB
  (not just echoed back).
- **Criterion 7380 — Assistant cannot edit transcripts or rename
  speakers.** Call `list_tools/0`, confirm the returned tool set is
  exactly `search_transcripts`/`read_transcript`/`attach_summary` with no
  edit/rename tool; cross-check no such tool exists anywhere in
  `lib/ear_witness_web/mcp_server/`.
- **Criterion 7381 — Revoking access shuts the assistant out.** Two
  independent checks: (a) toggle `#assistant-access-form` on
  `/settings` via the real browser and confirm the choice persists
  across a fresh page load (proves DB-backed, not socket-local state);
  (b) flip `EarWitness.Assistant.set_access/1` in the probe script and
  confirm `list_tools/0`/`search_transcripts/1` immediately return
  `{:error, :access_revoked}`.
- **Criterion 7382 — No network listener for the MCP surface.** `lsof
  -nP -a -p <app-pid> -i` against the actual running app process;
  `grep` `lib/ear_witness_web/router.ex` for any `/mcp` route; confirm
  `config/config.exs` sets `transport: :stdio` with no `:port` key; and
  confirm `EarWitnessWeb.McpServer.Server.start_link` is never called
  anywhere (so nothing MCP-related is even running to listen on
  anything).

## Result Path

`.code_my_spec/qa/868/brief.md` (this file) — findings recorded as
issues via `create_issue`; DB attempt via `submit_qa_result`.

## Setup Notes

The app process (PID confirmed via `ps`/`lsof` during this session) was
started via `mix run --no-halt priv/repo/qa_server.exs` with `-noshell`
and no `-sname`/`-name` — not a distributed node, so no remote console
was available or used. All probing against the real DB went through a
disposable `mix run --no-start` script
(`qa868_mcp_probe.exs`, kept only in the QA scratchpad, not committed)
that starts just `ecto_sqlite3` + `EarWitness.Repo`, matching the
established `qa_seeds.exs` pattern — no second app instance, no port
collision, no window. The probe's `attach_summary` write to recording
37 was reverted (`summary` set back to `NULL`) immediately after
confirming the round-trip, so the shared QA fixture library is
unchanged. Assistant access was left `disabled` (its default) at the
end of the session.

BDD spex for all 6 criteria (`test/spex/868_.../\*_spex.exs`) pass
(`mix spex`, 0 failures) — but by design they call
`EarWitnessWeb.McpServer.*` functions directly rather than driving a
real stdio MCP connection (each file's own moduledoc says so). This
session's `mix run --no-start` probe against the real running app's DB
was done specifically to get evidence beyond that self-acknowledged gap.
