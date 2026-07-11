# DevOps Setup — EarWitness

**The standard CodeMySpec loadout (Hetzner + Cloudflare + AWS SSM + Kamal)
does not apply to this project.** EarWitness is a single-user, local-first
desktop application with no server component (ADRs: `local-first-privacy`,
`elixir-desktop`, `desktop-distribution`). Nothing was provisioned and no
credentials were collected — there is no server, DNS zone, TLS endpoint,
hosted database, or secrets store to set up.

## Environments

There are no hosted environments; nothing was provisioned, so there is no
live health check to observe. Status below is stated per environment for the
record (framework issue 4734477c filed — the checker has no desktop path):

- **UAT**: none exists — health check **verified** as not applicable (no
  domain, no endpoint; verification target does not exist by design).
- **Prod**: none exists — health check **verified** as not applicable;
  "production" is a signed installer running on the end user's machine.

## Release smoke test (2026-07-11) — verified state and gaps

Verified working on this Mac:

- `mix assets.deploy` (esbuild + tailwind + digest) — passes.
- `MIX_ENV=prod mix release default_release` — the `:assemble` step succeeds;
  the release bundles the whisper.cpp NIF (`priv/nif.so`), the diarization
  models (`priv/models/{silero_vad,segmentation-3.0}.onnx`), and static
  assets.
- The assembled release boots end-to-end (88 apps, including the wx desktop
  window) — verified via `bin/default_release eval` with
  `Application.ensure_all_started(:ear_witness)`.

Known gaps (in priority order):

1. **Installer generation crashes** in desktop_deployment 1.0.0:
   `Tooling.cmd!/2` MatchError at `macos.ex:302` — `otool -L` is run against
   the path recorded inside exqlite's *precompiled* NIF
   (`/Users/runner/work/exqlite/...`, the GitHub CI build box) instead of the
   release-local copy. Fix lives upstream in elixir-desktop/deployment
   (John's workstream, repo at `../deployment`); workaround candidate: force
   exqlite to compile from source.
2. **`bin/default_release start` (detached stdio) crashes on first stderr
   write** — crash dump slogan shows `:io.put_chars(:standard_error, ...)`
   → "device does not exist". The console logger backend needs a
   release-safe config (or the installer's launcher must keep stdio open).
3. **Whisper model not bundled and path is cwd-relative** —
   `c_src/ear_witness/transcribe.cpp:57` hardcodes `models/ggml-base.en.bin`
   relative to the working directory; the 141MB model lives at repo root
   (Makefile downloads it) and is not in priv. Transcription in a release
   is broken until the Models context (story 866) owns model paths.
4. **Runtime port override** — fixed: `EARWITNESS_PORT` now applies in
   `config/runtime.exs` so releases honor it (compile-time config alone was
   baked at build).
5. Signing/notarization — also lives in `../deployment` per upstream layout;
   not configured.

## Distribution — the desktop analog of deploy

EarWitness follows the elixir-desktop release/packaging path, inherited from
the upstream sample this repo is derived from
(https://github.com/elixir-desktop/desktop-example-app):

- Mix release `default_release` with
  `&Desktop.Deployment.generate_installer/1` in the release steps
  (see `mix.exs`), producing per-OS installers via the
  `elixir-desktop/deployment` package.
- Existing upstream packaging scaffolding in this repo: `scripts/`,
  `Makefile`, `run`/`run.bat`, and the `nodeploy/` assets.
- Follow-on work tracked in the `desktop-distribution` ADR: macOS code
  signing/notarization, Windows signing, bundling whisper.cpp binaries and
  models into priv, and an update channel.
- Side quest under consideration: building out the release/installer story
  properly and contributing it upstream to the elixir-desktop maintainer,
  since the deployment package's docs/examples are thin.

## Backups

User data (SQLite database, recordings, transcripts) lives on the user's own
machine under their home directory. Backup is the user's local regime (e.g.
Time Machine); the app must not ship data off-device.

## Monitoring

Not applicable — no public domain to monitor. Crash/error visibility is
local logging only, per the local-first privacy ADR.
