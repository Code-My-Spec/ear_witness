# Use whisper.cpp for on-device transcription

## Status
Accepted

## Context
The core product promise (persona: hearing-documenter) is transcription where
audio never leaves the machine, at zero marginal cost, on multi-hour
recordings. Cloud STT APIs are disqualified by privacy and cost; the engine
must run on consumer laptops without a discrete GPU.

## Options Considered
- **whisper.cpp (vendored, built via elixir_make)** — C/C++ port of OpenAI
  Whisper; CPU-friendly (BLAS/Metal), no Python runtime, ships as a binary
  inside the release. Already integrated (v1.9.1) and passing tests.
- **Bumblebee/Nx Whisper** — pure-Elixir inference, but heavier memory, slower
  on CPU, and larger release artifacts (EXLA).
- **Cloud APIs (OpenAI, Deepgram, Rev)** — best accuracy/ops story, but
  violates the privacy constraint and costs ~$0.25–0.40+/audio-minute at
  documentation volume.

## Decision
Keep whisper.cpp v1.9.1, compiled by elixir_make from c_src/ with models in
models/ and invoked from `EarWitness.Transcribe`/`EarWitness.Transcription`.

## Consequences
- Release/installer must bundle the compiled binary and a model file; model
  download/selection UX is follow-on work.
- Accuracy tracks the chosen Whisper model size; long files are processed
  locally with no per-minute fees.
- Platform-specific builds (Metal on macOS, BLAS elsewhere) are handled in the
  Makefile.
