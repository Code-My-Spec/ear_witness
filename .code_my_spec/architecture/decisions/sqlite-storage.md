# Use SQLite (ecto_sqlite3) for local storage

## Status
Accepted

## Context
A single-user desktop app needs durable local storage for transcripts,
recordings metadata, and job state — with zero external services and zero
setup for the end user.

## Options Considered
- **SQLite via ecto_sqlite3** — embedded, file-based, no daemon; standard Ecto
  API; `EarWitness.Repo.initialize()` creates the DB on first boot.
- **Postgres** — richer concurrency and full-text search, but requires an
  installed server; unacceptable install burden for a downloadable app.
- **Plain files (JSON/Markdown)** — simple but loses querying, migrations, and
  Oban job storage.

## Decision
Keep SQLite through `ecto_sqlite3` (~> 0.12). The Repo lives in the
`EarWitness` domain and is initialized at application start when missing.

## Consequences
- Test sandboxing works via Ecto.Adapters.SQL.Sandbox.
- Write concurrency is limited (single writer); long transcription jobs should
  batch inserts.
- Full-text search over transcripts, if needed, uses SQLite FTS5 — follow-on
  decision when the search story lands.
