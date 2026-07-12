defmodule EarWitnessTest.RecordedDiarizer do
  @moduledoc """
  Replays recorded `EarWitness.Speakers.Diarizer.Onnx` output at the
  `EarWitness.Speakers.Diarizer` seam, mirroring
  `EarWitnessTest.RecordedTranscriptionEngine`.

  This is NOT a hand-written fake: every cassette under
  `test/fixtures/diarizer_cassettes/` is captured from the real ONNX
  segmentation + spectral-clustering + WeSpeaker-embedding pipeline
  running on `test/fixtures/diarize.raw` — a genuine two-person
  recording with real cross-talk moments (see
  `scripts/record_diarizer_cassettes.exs`, which regenerates them).
  Their timestamps are shifted to land on the fixed two-segment
  transcript `RecordedTranscriptionEngine` always produces in tests
  (0-3000ms, 3000-8000ms) — the underlying confidences, cluster
  assignments, and embeddings are exactly what the real pipeline
  produced for that real audio, just relabeled onto a different clock,
  the same way `RecordedTranscriptionEngine` replays a real transcript
  regardless of what (silent, fixture) WAV bytes were actually
  "transcribed".

  Since every spec's uploaded WAV is the same silent
  `EarWitnessSpex.WavFixture.short()` bytes, there is no real audio
  signal to key cassette selection off; this double keys off the
  recording's title instead (set to the imported filename — see
  `EarWitness.Recordings.import_recording/2`), the only thing that
  actually varies between BDD scenarios:

  - title contains "cross-talk" -> `cross_talk` (one confident speaker,
    one genuinely ambiguous/overlapping turn -> "Unknown")
  - title contains "alex" -> `known_voice` (both turns confident; its
    first turn always carries the *same* real embedding, so recordings
    named after the same person genuinely cosine-match each other)
  - anything else -> `two_speakers` (two confident, distinct speakers)
  """

  @behaviour EarWitness.Speakers.Diarizer

  @cassette_dir "test/fixtures/diarizer_cassettes"

  @impl true
  def diarize(recording) do
    with {:ok, json} <- File.read(cassette_path(recording)),
         {:ok, decoded} <- Jason.decode(json) do
      {:ok, Enum.map(decoded, &to_turn/1)}
    end
  end

  defp cassette_path(recording) do
    Path.join(@cassette_dir, cassette_name(recording.title || "") <> ".json")
  end

  defp cassette_name(title) do
    downcased = String.downcase(title)

    cond do
      String.contains?(downcased, "cross-talk") -> "cross_talk"
      String.contains?(downcased, "alex") -> "known_voice"
      true -> "two_speakers"
    end
  end

  defp to_turn(%{
         "start_ms" => start_ms,
         "end_ms" => end_ms,
         "cluster" => cluster,
         "confidence" => confidence,
         "embedding" => embedding
       }) do
    %{
      start_ms: start_ms,
      end_ms: end_ms,
      cluster: cluster,
      confidence: confidence,
      embedding: embedding
    }
  end
end
