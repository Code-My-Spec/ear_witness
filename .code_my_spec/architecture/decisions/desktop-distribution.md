# Distribute as native installers via desktop_deployment

## Status
Accepted

## Context
The persona downloads a desktop app onto a personal laptop — no IT
department, no server. Distribution means signed installers per OS, not
server hosting. (This replaces the pre-made Hetzner deployment decision,
which was removed as inapplicable: there is no server component to host.)

## Options Considered
- **elixir-desktop's desktop_deployment** — generates platform installers from
  the Mix release (`&Desktop.Deployment.generate_installer/1` is already in
  the release steps).
- **Manual packaging (create-dmg, WiX, AppImage)** — more control, much more
  per-platform work.

## Decision
Keep desktop_deployment to generate installers from the `default_release`
release definition.

## Consequences
- Code signing / notarization (macOS) and Windows signing certificates are
  follow-on work before public distribution.
- whisper.cpp binaries and model files must be included in the release priv
  so installers ship a working transcriber out of the box.
- Auto-update strategy is an open question — revisit when there are external
  users (candidate: download-and-replace with version check against
  earwitness.ai).
