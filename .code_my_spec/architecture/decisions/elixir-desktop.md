# Use elixir-desktop as the application shell

## Status
Accepted

## Context
EarWitness is a local-first desktop app: it captures audio, transcribes it
on-device, and stores everything locally. It needs a native window, a menubar
and tray icon, and OS integration on macOS/Windows/Linux, while the UI itself
is a Phoenix LiveView app.

## Options Considered
- **elixir-desktop (wxWidgets + wxWebView)** — runs the whole BEAM app locally
  and renders the LiveView UI in a native webview window; one language, one
  release; installer support via desktop_deployment. Cons: wxWidgets toolchain,
  smaller community.
- **Tauri/Electron shell + remote BEAM** — better-known shells, but adds a
  second toolchain (Rust/Node) and an IPC seam between shell and BEAM.
- **Plain web app** — no install story; disqualified by the persona's
  requirement that audio never leaves the machine and the app work offline.

## Decision
Keep elixir-desktop (`:desktop` ~> 1.5). The app already boots
`Desktop.Window` with a menubar and tray icon, and the whole product stays in
one Elixir release. `EarWitnessWeb.Application` supervises Repo, Endpoint, and
the Desktop window.

## Consequences
- UI is LiveView in a webview — standard Phoenix testing applies.
- Distribution uses desktop_deployment installers (see desktop-distribution).
- wx is required on the host; mobile targets pull the :bridge wx package.
