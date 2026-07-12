# EarWitness: Your AI Assistant Gets Its Keys (2026-07-11)

Story 868 is green — the MCP surface is real. Claude Code (or any MCP
client) can now, with your explicit opt-in from settings:

- **Search your conversation library** and get back real passages with
  speakers and timestamps.
- **Read full transcripts** — segments, attribution, and any attached
  summary.
- **Write exactly one thing**: attach a meeting summary to a recording,
  which then shows up in the app. No transcript editing, no speaker
  renaming — the spec literally asserts those tools don't exist.
- **Be shut out instantly** — revoke access in settings and every call
  returns access_revoked.

The transport is stdio only — the config carries no port because there is
no port; conversation data leaves the machine only through the assistant
you personally connected. Real Anubis tool components with schemas, not
stubs; the one honest TODO is a dedicated entry point for launching the
stdio server outside the GUI app (a windowed desktop app can't donate its
own stdin to JSON-RPC).

**Scoreboard: 64 of 69 scenarios green. Eight of ten stories complete.**
Every remaining red traces to one root: real multi-speaker diarization —
the voice-embedding clustering that turns "one blob of speech" into
"the adjudicator said X, the tenant said Y." That's the final boss.
