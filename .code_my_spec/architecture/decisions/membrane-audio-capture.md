# Use Membrane for audio capture and processing

## Status
Accepted

## Context
EarWitness records live audio (microphone, and eventually system/meeting
audio) into files that feed the transcription engine. It needs a composable
pipeline: capture → mix → parse/convert raw audio → write to file.

## Options Considered
- **Membrane Framework** — Elixir-native multimedia pipelines; existing deps
  cover portaudio capture (membrane_portaudio_plugin), mixing
  (membrane_audio_mix_plugin), raw-audio parsing, and file sinks. Already
  integrated under `EarWitness.Audio`.
- **Direct portaudio NIF / custom C** — less code reuse, more unsafe surface.
- **OS-level tools (ffmpeg subprocess)** — capture via CLI is brittle across
  platforms and harder to compose with live level metering/VAD.

## Decision
Keep Membrane (core ~> 1.0 plus portaudio, audio_mix, raw_audio, file
plugins) as the audio capture/processing layer.

## Consequences
- System-audio tap targets (PM decision 2026-07-11, story 861): **macOS —
  Core Audio process taps** (macOS 14.4+, no driver install); **Windows —
  WASAPI loopback**, both in v1. Linux later. Integration details still need
  a research pass before implementation.
- Membrane's supervision integrates with the app's OTP tree; pipeline crashes
  don't take down the UI.
