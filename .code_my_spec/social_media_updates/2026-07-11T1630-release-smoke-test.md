# EarWitness: Release Smoke Test — Closer Than Expected (2026-07-11)

Question of the afternoon: can this thing actually ship? Answer: closer than
we thought, with a precise gap list instead of vibes.

**What works today, verified live:**

- Production asset build (esbuild + Tailwind v4 + digest) — clean.
- `mix release` assembles a complete release: whisper.cpp compiled in as a
  NIF, the VAD + speaker-segmentation ONNX models bundled, static assets
  digested.
- The assembled release **boots end-to-end on a clean BEAM — 88 apps
  including the native desktop window.**

**The gap list (each one root-caused, not guessed):**

1. Installer generation crashes in elixir-desktop's deployment tooling: it
   runs `otool -L` against the path baked into exqlite's *precompiled* NIF —
   a GitHub CI runner path that doesn't exist on any real machine. Fix
   belongs upstream (the founder is taking that one on directly — the side
   quest begins).
2. Detached launches (`bin/app start`) die on the first stderr write —
   the logger needs a release-safe backend config.
3. The whisper model (141MB) isn't bundled, and the NIF looks for it
   relative to the working directory. Already covered by the "working
   transcriber minutes after install" story — the Models context will own
   model paths and downloads.
4. Fixed along the way: `EARWITNESS_PORT` now works for releases (runtime
   config, not compile-baked).

Signing and notarization also live upstream in elixir-desktop/deployment.
When that side quest lands, EarWitness ships as a real signed installer.
