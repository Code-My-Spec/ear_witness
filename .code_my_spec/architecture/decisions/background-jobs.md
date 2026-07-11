# Use Oban for background transcription jobs

## Status
Accepted

## Context
Transcribing a multi-hour recording takes many minutes of CPU time; it must
not block the UI and should survive app restarts (resume/retry). The app
needs a durable local job queue.

## Options Considered
- **Oban (on the local SQLite DB)** — durable, retryable, observable jobs
  stored next to the data they process; already a dep and configured
  (`testing: :inline` in test).
- **Task.Supervisor / GenServer queue** — simple but jobs die with the
  process; no retry or persistence for long transcriptions.

## Decision
Keep Oban (~> 2.17) with the SQLite-backed Ecto repo for transcription and
post-processing (diarization, export) jobs.

## Consequences
- Job lifecycle (queued → transcribing → done/failed) is visible to the UI via
  Oban telemetry/PubSub.
- SQLite's single-writer model means job workers should chunk DB writes;
  concurrency limits stay low (CPU-bound work anyway).
