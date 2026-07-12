# Local-first: no audio or transcript leaves the device

## Status
Accepted

## Context
The persona research (hearing-documenter) shows the entire buying reason for
EarWitness is privacy: audio and transcripts of sensitive proceedings and
confidential meetings must never touch a third-party server, no bot may join
a call, and transcription must be free at volume. This is a product
constraint that every technical decision must respect.

## Decision
All capture, transcription, diarization, storage, and search run on-device.
The app makes no network calls with user content. Permitted network use is
limited to: model downloads, version checks, and (if ever added) explicitly
opt-in features — each requiring its own ADR before introduction.

Explicit opt-in exceptions (PM-decided, Three Amigos 2026-07-11):

- **Support widget** (support-widget ADR): user-initiated feedback/chat
  content the user explicitly submits.
- **Meeting bots** (story 869): a user-dispatched bot joins a meeting as a
  visible participant for meetings the user can't attend. Constraint: any
  external component (headless client, relay) may only *pipe audio
  through* — conversation data is stored and processed exclusively on the
  user's machine, and the relay retains nothing. This is per-dispatch
  opt-in by construction; the tap capture path (story 861) remains fully
  local and involves no bot ever.

## Consequences
- Disqualifies cloud STT/LLM post-processing by default; any future AI
  summary feature must run locally or be explicitly opt-in.
- Marketing/positioning can make a hard claim ("your audio never leaves your
  machine") that competitors with bots and cloud backends cannot.
- No server-side telemetry: debugging relies on local logs the user chooses
  to share.
