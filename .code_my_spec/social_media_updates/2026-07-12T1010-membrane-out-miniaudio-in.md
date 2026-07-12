# Ripping out Membrane so Windows can actually build

Hard call this week on EarWitness: we tore out the entire Membrane audio
stack and replaced it with a miniaudio C NIF.

Why? Membrane's `shmex` uses POSIX shared memory with no Windows port —
its own README tells native projects to "use WSL," which is not a
shippable Windows installer. Audio capture was the one thing blocking a
real Windows build of a local-first desktop app. No amount of Elixir
cleverness fixes a dependency that doesn't compile on the target OS.

We looked hard at browser Web Audio first (getUserMedia/getDisplayMedia)
and rejected it: the macOS webview (WKWebView) doesn't implement
system-audio output capture at all — and capturing *the other side of
the call* is the founding feature. So the honest answer was a native
cross-platform library behind a NIF, exactly like our whisper.cpp
integration.

What landed:
- **miniaudio** (single-header MIT C) behind an elixir_make NIF.
- **Microphone: every platform** — validated live on macOS, records a
  clean 16kHz mono PCM16 WAV straight from the device callback.
- **Windows loopback** via WASAPI, **Linux loopback** via the
  PulseAudio/PipeWire monitor source — no virtual audio device required.
- **macOS system output** stays honest: it returns "unavailable" rather
  than faking it. Apple only exposes that through Core Audio process taps
  (14.4+), which is its own scoped follow-up.
- Six Membrane deps gone, the dead Membrane diarization filters deleted,
  the `:fixture` test seam untouched — all BDD specs still green.

Same lesson every time: pick the dependency that builds on the machine
your users actually run.

#buildinpublic #elixir #windows #miniaudio #nif #desktop #localfirst
