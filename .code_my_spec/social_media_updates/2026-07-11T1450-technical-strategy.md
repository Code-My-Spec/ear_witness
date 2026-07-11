# EarWitness: Technical Strategy Locked In (2026-07-11)

EarWitness now has its architecture decision records. The through-line is one
hard product constraint from persona research: **no audio or transcript ever
leaves the device.**

Project-specific ADRs (all documented in `.code_my_spec/architecture/`):

- **Local-first privacy** — the load-bearing decision. All capture,
  transcription, and storage on-device; network use limited to model
  downloads and version checks. It's a positioning claim competitors with
  meeting bots and cloud backends can't make.
- **elixir-desktop shell** — the whole product is one Elixir release: BEAM +
  Phoenix LiveView rendered in a native wxWebView window with menubar/tray.
- **whisper.cpp v1.9.1** — CPU-friendly on-device transcription compiled via
  elixir_make; zero per-minute fees on multi-hour hearing audio.
- **Membrane** — composable audio capture/mix/file pipelines (portaudio).
- **SQLite (ecto_sqlite3)** — zero-setup embedded storage; FTS5 on deck for
  transcript search.
- **Oban** — durable background jobs so multi-hour transcriptions survive
  restarts and never block the UI.
- **desktop_deployment** — native installers per OS (replaces the standard
  server-hosting decision; there is no server).
- **Speaker diarization (proposed)** — ONNX models via ortex + embedding
  clustering, validated in an earlier Python spike; research task queued to
  pick models before implementation.

Also pruned the standard-stack decisions that don't apply to a single-user
desktop app: server hosting, auth, transactional email, browser E2E.
