# Speaker diarization via ONNX models (ortex) + clustering

## Status
Implemented (`EarWitness.Speakers.Diarizer.Onnx` and friends under
`lib/ear_witness/speakers/diarizer/`) — see "Implementation notes" below
for what shipped versus what remains scoped out.

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

## Implementation notes

- Within-recording attribution: `segmentation-3.0.onnx` runs once over
  the whole recording (not pyannote's sliding-window-plus-overlap-add —
  see the moduledoc on `EarWitness.Speakers.Diarizer.Onnx` for why a
  single pass is honest for short/medium recordings and what's cut),
  producing per-frame local speaker classes; contiguous runs are
  refined into consistent speaker identities via real spectral
  clustering (`EarWitness.Speakers.Diarizer.SpectralClustering` — cosine
  affinity, normalized Laplacian, `Nx.LinAlg.eigh`, eigengap `k`
  selection, k-means).
- Cross-recording matching: a WeSpeaker ResNet34 voice-embedding model
  (`priv/models/voxceleb_resnet34_LM.onnx`, fetched from
  https://huggingface.co/Wespeaker/wespeaker-voxceleb-resnet34-LM,
  sha256 `7bb2f06e9df17cdf1ef14ee8a15ab08ed28e8d0ef5054ee135741560df2ec068`)
  is fed 80-bin log-mel features extracted by a from-scratch
  `EarWitness.Speakers.Diarizer.Fbank` (no Kaldi/torchaudio dependency
  bundled) — not guaranteed bit-exact with the model's training
  preprocessing; `EarWitness.Speakers.@match_threshold` is calibrated
  from real measurements against `test/fixtures/diarize.raw` rather
  than a paper-default value, and should be retuned against a broader
  set of real recordings.
- Long recordings (beyond a few minutes) are the main known quality gap
  versus pyannote's own pipeline — the sliding-window aggregation that
  would fix it is the still-unfinished part of
  `EarWitness.Audio.SpeakerDiarizationSplitter`/`Windows` (a different,
  Membrane-streaming-pipeline concern from this post-hoc batch pass).
- **Fix (QA issue d0d3bfa7, story 862 criterion 7339):** within-recording
  clustering originally ran `SpectralClustering` over each confident
  run's *mean segmentation-model class-activation profile*. On a clean
  two-voice recording (alternating solo turns separated by silence) the
  segmentation model reuses the same local A/B/C slot for every turn,
  so that profile is nearly identical across turns regardless of who's
  speaking, collapsing every speaker into one cluster — a real bug the
  BDD cassette never caught because its source recording (a natural,
  messier conversation) happened to already use different local slots
  per speaker. Fixed by extracting a WeSpeaker embedding per confident
  run (not once per cluster) and clustering on *those* instead — see
  `EarWitness.Speakers.Diarizer.Onnx.build_turns/3`. Doing so also
  exposed that real voice embeddings don't form as clean a
  block-diagonal affinity matrix as activation profiles did (cross-
  speaker cosine similarity isn't negligible), so
  `SpectralClustering.sparsify/1` now drops each row's edges that are
  weak relative to that row's own strongest match before building the
  Laplacian — see that module's moduledoc for why a row-max-relative
  threshold was used over a row-mean one.
