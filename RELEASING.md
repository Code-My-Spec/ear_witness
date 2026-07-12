# Releasing EarWitness

Installers for **macOS, Linux, and Windows** are built and published entirely by
GitHub Actions. You do not build or sign anything locally — you tag, and CI does
the rest.

## Cut a release

1. Make sure `master` is green — the three installer workflows must pass on the
   latest `master` (check the Actions tab). A red build means the release won't
   produce that platform's installer.
2. (Optional) bump `@version` in `mix.exs`. Installer files are named from it
   (e.g. `EarWitness-<version>.dmg`).
3. Tag and push:
   ```sh
   git push origin master
   git tag vX.Y.Z            # e.g. v1.2.0-beta.3 (beta) or v1.2.0 (real)
   git push origin vX.Y.Z
   ```
4. CI builds all three installers for that tag and attaches them to the GitHub
   Release: `.dmg` (macOS), `.run` (Linux), `.exe` (Windows).
5. For a beta/prerelease, mark it:
   ```sh
   gh release edit vX.Y.Z --repo Code-My-Spec/ear_witness --prerelease
   ```
   (The workflows publish as a normal release by default.)

That's the whole process. No local `mix desktop.installer`, no manual uploads.

## What CI does

Three workflows in `.github/workflows/`, each triggered on push to `master`
(build only) and on `v*` tags (build **and** publish to the Release):

| Platform | Workflow | Output | Notes |
|---|---|---|---|
| macOS  | `macos-installer.yml`  | `.dmg` | Builds wxWidgets 3.2.6 + OTP with a verified wx driver; adhoc-signs. |
| Linux  | `linux-installer.yml`  | `.run` | wxWidgets (GTK) + OTP from source; makeself installer. |
| Windows| `windows-installer.yml`| `.exe` | Official OTP ships wx; miniaudio (WASAPI) capture; whisper NIF skipped. |

## Signing / notarization — the one gap for real distribution

Installers are currently **adhoc-signed / unsigned**. They install and run, but
show OS warnings to end users:
- **macOS**: "unidentified developer" → right-click → Open (or clear quarantine).
- **Windows**: SmartScreen "unknown publisher" → More info → Run anyway.

To ship properly signed (CI already skips signing gracefully when the secrets
are absent, which is the current state):

- **macOS** (needs an Apple Developer account): add a repo secret `MACOS_PEM`
  (your Developer ID Application certificate as PEM). `mix desktop.installer`
  signs with it automatically. Notarize the resulting `.dmg`:
  `mix desktop.notarize <apple_id> <app_specific_password> <team_id> _build/prod/*.dmg`.
- **Windows**: provide a code-signing cert (`rel/win32/app_cert.pem` +
  `app_key.pem`) and set `WIN32_KEY_PASS`; deployment signs via osslsigncode.

## Known gaps (not release blockers)

- **Transcription**: whisper model bundling is WIP. On Windows the whisper NIF
  is skipped entirely (no-op `Makefile.win`); miniaudio capture works.
- **Windows GUI**: the wx window is present and the capture NIF is verified
  (WASAPI device enumeration + loopback), but the window hasn't been
  eyeball-tested on a real Windows desktop session.

## Dependency note

`mix.exs` tracks `desktop_deployment` at branch
`fix/macos-otool-missing-precompiled-nif-path` (elixir-desktop/deployment#15 —
the macOS installer fixes). Once that PR merges upstream, repoint it to `main`.
