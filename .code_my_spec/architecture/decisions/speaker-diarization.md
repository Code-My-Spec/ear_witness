# Speaker diarization via ONNX models (ortex) + clustering

## Status
Proposed

## Context
Hearing transcripts are only quotable if you can tell who said what
(adjudicator vs landlord vs tenant vs interpreter). Whisper alone does not
attribute speakers. A local diarization step must run on-device like
everything else.

## Options Considered
- **ONNX models via ortex (VAD + speaker embeddings) + clustering in Elixir/Nx**
  — ortex and nx are already deps; VAD fixtures (silero-style vad.raw) exist in
  the test suite; a Python spike proved the clustering approach.
- **whisper.cpp tinydiarize** — built into the engine but experimental and
  limited to 2-speaker turn detection.
- **pyannote (Python)** — best quality, but drags a Python runtime into a
  shippable desktop app; disqualified for distribution weight.

## Decision
Proposed: run VAD and speaker-embedding ONNX models through ortex, cluster
embeddings (as validated in the Python transcribe spike), and merge speaker
segments with Whisper timestamps. Needs a `research_topic` pass to pick the
embedding model and clustering parameters before implementation.

## Consequences
- Adds model files to the bundle; increases first-run download size.
- Diarization quality on far-field hearing audio is the main risk — validate
  against real recordings early.
