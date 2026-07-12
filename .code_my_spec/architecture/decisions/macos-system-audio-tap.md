# macOS system-audio output capture via Core Audio process taps

## Status
Proposed (2026-07-12) — the macOS half of the capture story that
[miniaudio-capture](miniaudio-capture.md) deliberately leaves out.

## Context
Capturing the *output* audio of a call (the other participant's voice) is
EarWitness's founding capability — record both sides of a meeting with no
bot in the room. On Windows and Linux this is solved by miniaudio
(WASAPI loopback / PulseAudio monitor). On **macOS there is no
cross-platform path**: neither miniaudio (issue #875, unimplemented) nor
WKWebView Web Audio (no `getDisplayMedia` audio) can do it. Apple exposes
system-audio capture only through macOS-specific APIs.

## Options Considered
- **Core Audio process taps — `AudioHardwareCreateProcessTap` (macOS
  14.4+).** The modern, audio-only, driverless path: create a process tap
  bound to an aggregate device, receive system/app output as an input
  stream, gated by a one-time user permission. No kernel extension, no
  reboot, no rerouting of what the user hears. Poorly documented but
  demonstrated by Apple sample code (insidegui/AudioCap). Requires macOS
  14.4+.
- **ScreenCaptureKit audio (macOS 13+).** Also driverless, but
  "screen-recording-shaped": needs the Screen Recording permission, shows
  the menubar recording indicator, and rides screen-capture infrastructure
  for an audio-only feature — heavier and odder UX for a transcription app.
  Broader OS support (13+) than Core Audio taps.
- **Virtual audio device (BlackHole / Loopback / Soundflower).** The
  legacy approach: user installs a driver, reboots for the security
  approval, and reroutes output through the virtual device (changing what
  they hear unless an aggregate device is configured). miniaudio can then
  capture from that device as an ordinary input. Worst UX; a fallback for
  pre-14.4 macOS.

## Decision (proposed)
Target **Core Audio process taps (14.4+)** as the primary macOS
system-output path — cleanest UX, audio-only, no driver. Implement as a
small native macOS module (Objective-C/C or Swift) behind the same
`EarWitness.Audio.Pipeline` / `capture_source` seam miniaudio uses, so the
rest of the app is agnostic to which platform backend produced the audio.
Keep ScreenCaptureKit and/or a BlackHole path as documented fallbacks for
older macOS if a v1 minimum below 14.4 is required — a `research_topic`
pass should confirm the minimum macOS version and validate tap → aggregate
device → PCM plumbing before implementation.

## Consequences
- macOS "record both sides" is gated on this module; until it ships, macOS
  captures microphone + imported files only (current behavior).
- Pins a macOS floor of 14.4 for the primary path (or 13 via
  ScreenCaptureKit) — a distribution decision to confirm with the
  desktop-distribution ADR.
- Adds a permission prompt to the first system-audio capture (surfaced by
  story 861's "guided setup" criterion).
- Native code is macOS-only and separate from the miniaudio NIF; the two
  meet only at the capture-source seam.
