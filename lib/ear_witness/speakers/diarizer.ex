defmodule EarWitness.Speakers.Diarizer do
  @moduledoc """
  Seam for turning a recording's audio into speaker turns. Selected via
  `config :ear_witness, :diarizer` — production points at
  `EarWitness.Speakers.Diarizer.Onnx` (VAD-free segmentation model +
  spectral clustering + voice embeddings, all on-device via ortex), the
  test environment at `EarWitnessTest.RecordedDiarizer`, which replays
  recorded real output rather than running the ONNX models, mirroring
  `EarWitness.Transcription.Engine` / `EarWitnessTest.RecordedTranscriptionEngine`.

  `EarWitness.Speakers.diarize_transcript/1` calls the configured
  diarizer once per (not-yet-diarized) transcript and maps each
  transcript segment onto whichever returned turn overlaps it most.
  """

  alias EarWitness.Recordings.Recording

  @typedoc """
  One detected speaker turn.

  - `:cluster` — an opaque identifier for "the same voice", unique only
    within the turns returned by a single `diarize/1` call (two turns
    with the same `:cluster` are the same speaker within this
    recording; nothing about the value itself is meaningful).
  - `:confidence` — how sure the diarizer is that this turn belongs to
    one identified speaker, `0.0..1.0`. Overlapping or ambiguous speech
    is returned as its own low-confidence turn (`cluster: nil`) rather
    than attributed to either candidate speaker.
  - `:embedding` — a voice-signature vector for this turn's speaker,
    suitable for cosine-similarity matching against
    `EarWitness.Speakers.Speaker.embedding`, or `nil` when the turn
    isn't confident enough to extract one from.
  """
  @type turn :: %{
          required(:start_ms) => non_neg_integer(),
          required(:end_ms) => non_neg_integer(),
          required(:cluster) => term() | nil,
          required(:confidence) => float(),
          required(:embedding) => [float()] | nil
        }

  @doc "Detects speaker turns across a recording's whole audio file."
  @callback diarize(Recording.t()) :: {:ok, [turn()]} | {:error, term()}
end
