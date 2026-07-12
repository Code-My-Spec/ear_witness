# Architecture Decision Records — EarWitness

Index of every ADR in `.code_my_spec/architecture/decisions/`.

## Project-specific decisions

| ADR | Status |
|---|---|
| [local-first-privacy](decisions/local-first-privacy.md) — no audio or transcript leaves the device | Accepted |
| [elixir-desktop](decisions/elixir-desktop.md) — application shell (wxWidgets + LiveView webview) | Accepted |
| [whisper-cpp-transcription](decisions/whisper-cpp-transcription.md) — on-device speech-to-text | Accepted |
| [membrane-audio-capture](decisions/membrane-audio-capture.md) — audio capture/processing pipelines | Accepted |
| [sqlite-storage](decisions/sqlite-storage.md) — local storage via ecto_sqlite3 | Accepted |
| [background-jobs](decisions/background-jobs.md) — Oban job queue for transcription | Accepted |
| [desktop-distribution](decisions/desktop-distribution.md) — native installers via desktop_deployment | Accepted |
| [speaker-diarization](decisions/speaker-diarization.md) — ONNX (ortex) + clustering; needs research_topic | Proposed |
| [anubis-mcp](decisions/anubis-mcp.md) — local MCP server via Anubis on the app endpoint | Accepted |
| [support-widget](decisions/support-widget.md) — CodeMySpec chat/feedback over deploy-key Slipstream | Accepted |
| [asset-pipeline](decisions/asset-pipeline.md) — esbuild + Tailwind v4 + vendored DaisyUI 5 (dart_sass removed) | Accepted |
| [meeting-bot-relay](decisions/meeting-bot-relay.md) — config-selected seam for joining a real meeting; no vendor chosen yet | Proposed |

## Standard-stack decisions (pre-made)

| ADR | Status |
|---|---|
| [elixir](decisions/elixir.md) | Accepted |
| [phoenix](decisions/phoenix.md) | Accepted |
| [liveview](decisions/liveview.md) | Accepted |
| [tailwind](decisions/tailwind.md) | Accepted |
| [daisyui](decisions/daisyui.md) | Accepted |
| [bdd-testing](decisions/bdd-testing.md) (SexySpex) | Accepted |
| [req_cassette](decisions/req_cassette.md) | Accepted |
| [dotenvy](decisions/dotenvy.md) | Accepted |

## Removed pre-made decisions

Inapplicable to a single-user local desktop app (no server, no accounts, no
email): `hetzner-deployment` (replaced by desktop-distribution),
`phx-gen-auth`, `pow-assent-integrations`, `resend`, `wallaby` (LiveView is
exercised via Phoenix.LiveViewTest inside spex; no external browser needed).
