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
