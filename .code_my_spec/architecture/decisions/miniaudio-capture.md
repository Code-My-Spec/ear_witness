# Audio capture via miniaudio (C NIF), replacing Membrane/PortAudio

## Status
Accepted (2026-07-12) — supersedes the capture role of
[membrane-audio-capture](membrane-audio-capture.md).

## Context
EarWitness must run as a real desktop app on **macOS, Windows, and Linux**.
The Membrane/PortAudio capture stack does not build on Windows: Membrane's
`shmex` uses POSIX shared memory (`sys/mman.h`) with no Windows port and no
PR adding one, and Membrane's own README says native-code projects should
"use WSL." WSL is not a shippable Windows installer. So the capture layer
is the concrete blocker to a Windows build.

Two replacement directions were investigated with equal rigor (see
"Feasibility" below): browser Web Audio (`getUserMedia`/`getDisplayMedia`)
and a native cross-platform C library (miniaudio). Browser capture was
rejected because WKWebView (elixir-desktop's macOS webview) does not
implement `getDisplayMedia` audio at all — there is no web-API path to
system-audio *output* capture on macOS, which is the product's founding
capability.

## Feasibility (verified 2026-07-12)

Microphone ("my voice") is easy everywhere. The hard, decisive axis is
**system-audio output** ("the other side of the call"):

| Platform | Microphone | System output (loopback) |
|---|---|---|
| Windows | miniaudio ✓ | miniaudio native **WASAPI loopback** ✓ (no virtual device) |
| Linux | miniaudio ✓ | miniaudio via PulseAudio/PipeWire **monitor** source ✓ |
| macOS | miniaudio ✓ | **not miniaudio** — see [macos-system-audio-tap](macos-system-audio-tap.md) |

- miniaudio loopback is WASAPI-only (Windows) plus indirect monitor-device
  capture on PulseAudio/PipeWire (Linux). macOS loopback is an open,
  unimplemented miniaudio feature request (mackron/miniaudio issue #875).
- macOS system-output capture is irreducibly native and macOS-specific —
  no cross-platform library (miniaudio, browser, cpal) solves it, because
  Apple only exposes it via Core Audio process taps (14.4+) or
  ScreenCaptureKit (13+). That was already true under Membrane (the prior
  ADR flagged the macOS tap as unimplemented), so this direction loses
  nothing there.

## Options Considered
- **miniaudio via C NIF (chosen).** Single-header MIT C library; Windows
  WASAPI (+ loopback), macOS Core Audio, Linux ALSA/PulseAudio/PipeWire.
  Builds on Windows. Integrates through `elixir_make` + a small C NIF —
  the exact pattern this repo already uses for whisper.cpp
  (`c_src/ear_witness/transcribe.cpp`). Prior art: an Elixir Forum user
  (octetta, thread 63541) enumerates devices and streams frames via a
  miniaudio callback in "~30 lines of C."
- **Browser Web Audio** — rejected: no macOS system-output path in
  WKWebView.
- **cpal (Rust) via Rustler** — weaker/less-mature loopback support, and
  also no macOS loopback; adds a Rust toolchain the repo doesn't otherwise
  need.
- **Keep Membrane, add a Windows-only native path** — leaves the six
  Membrane deps + shmex + dead Membrane diarization filters in place and
  still needs bespoke Windows native code; more surface, less unification.

## Decision
Replace Membrane with **miniaudio behind a C NIF** as the capture backend
for microphone (all platforms) and system-output loopback (Windows,
Linux). Remove `membrane_core`, `membrane_portaudio_plugin`,
`membrane_audio_mix_plugin`, `membrane_raw_audio_format`,
`membrane_raw_audio_parser_plugin`, and `membrane_file_plugin`, and delete
the now-dead Membrane diarization filters (`EarWitness.Audio.VADSplitter`,
`SpeakerDiarizationSplitter`, `Windows`, the VAD pipelines) — the real
diarizer already runs ortex on whole files, not a Membrane graph.

macOS system-output capture is a separate native module — see
[macos-system-audio-tap](macos-system-audio-tap.md).

Integration shape (implementation-phase detail): a capture thread inside
the NIF pushes PCM buffers to an Elixir process via `enif_send` (matching
the desktop app's in-process NIF model), or an Elixir Port wrapping the
same C for crash isolation. Lean NIF-with-thread to match the existing
whisper NIF; revisit if scheduler safety pushes toward a Port.

## Consequences
- **Windows unblocks.** The capture layer builds without shmex.
- Contained by construction: capture already sits behind
  `EarWitness.Audio.Pipeline` with a `capture_source` seam and a
  `:fixture` test double, so the contexts, LiveViews, and all 69
  fixture-based BDD specs are untouched — only `Audio.Pipeline`'s real
  backend and the NIF change. The `capture_source` value moves from
  `:portaudio` toward `:miniaudio` (+ the macOS tap).
- Simpler dependency tree; a new C NIF to build per platform (already the
  case for whisper.cpp, so the toolchain and installer story exist).
- Microphone-level metering/VAD that Membrane filters used to provide moves
  into the miniaudio callback or the Elixir side.
- macOS system-output remains gated on the Core Audio tap module; until it
  lands, macOS captures microphone (and imported files) only — same state
  as today.
