# Asset pipeline: esbuild + Tailwind v4 + DaisyUI

## Status
Accepted

## Context
The inherited codebase built assets with esbuild + dart_sass (custom SCSS).
The standard-stack ADRs (tailwind, daisyui) assume utility-first styling,
and generated CodeMySpec UI (chat widget) ships DaisyUI-classed markup.

## Decision
Switched (2026-07-11, operator-directed): dart_sass is gone. CSS builds with
the Tailwind v4 standalone CLI (`{:tailwind, "~> 0.3"}`, v4.1.7) with
DaisyUI 5 as a vendored plugin (`assets/vendor/daisyui.js`, no node build).
`assets/css/app.css` is the entry (`@import "tailwindcss"` + `@plugin
"../vendor/daisyui"`); the old SCSS survives as `assets/css/legacy.css`
imported at the end (Tailwind v4 handles its nesting natively), to be
retired as the old todo UI is replaced by the new surfaces.

## Consequences
- The chat widget's DaisyUI markup renders styled immediately.
- New surfaces (RecordingLive, TranscriptLive, etc.) are built DaisyUI-first.
- `mix assets.deploy` runs esbuild + tailwind + digest; dev watcher rebuilds
  on change. `legacy.css` is tech debt with a scheduled death.
