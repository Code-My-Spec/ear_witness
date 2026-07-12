# Regenerates test/fixtures/diarizer_cassettes/*.json from the REAL
# EarWitness.Speakers.Diarizer.Onnx pipeline run against the real
# test/fixtures/diarize.raw recording (a genuine two-person conversation
# with a few natural cross-talk moments — verified by inspecting the
# segmentation model's own per-frame class predictions).
#
# Per the project's "doubles replay recorded real output" rule, cassette
# turns are picked from this one real diarization run (never hand-typed
# numbers) and their timestamps are shifted to line up with the fixed
# two-segment transcript the RecordedTranscriptionEngine always produces
# in tests (0-3000ms "Testing 1, 2, 3, testing.", 3000-8000ms "1, 2, 3.")
# — see EarWitnessTest.RecordedDiarizer's moduledoc for why that
# remapping is honest.
#
# Run with: mix run scripts/record_diarizer_cassettes.exs

Application.ensure_all_started(:ortex)

raw = File.read!("test/fixtures/diarize.raw")
samples = Nx.from_binary(raw, :f32)
turns = EarWitness.Speakers.Diarizer.Onnx.diarize_samples(samples)

find_turn = fn start_ms ->
  Enum.find(turns, fn t -> t.start_ms == start_ms end) || raise "no turn at #{start_ms}"
end

# Two confident, clearly-distinct-speaker turns (cluster 0 = the "C"
# voice, cluster 1 = the "B" voice — verified consistent across the
# whole 30s recording).
speaker_one_turn = find_turn.(10_952)
speaker_two_turn = find_turn.(14_721)

# A genuine overlap ("B+C" powerset class) turn: real cross-talk, low
# confidence, no clean single-speaker embedding.
overlap_turn = find_turn.(10_445)

remap = fn turn, start_ms, end_ms, cluster ->
  %{
    "start_ms" => start_ms,
    "end_ms" => end_ms,
    "cluster" => cluster,
    "confidence" => turn.confidence,
    "embedding" => turn.embedding
  }
end

write_cassette = fn name, cassette_turns ->
  path = Path.join("test/fixtures/diarizer_cassettes", name <> ".json")
  File.write!(path, Jason.encode!(cassette_turns, pretty: true))
  IO.puts("wrote #{path}")
end

# two_speakers.json — the default: both transcript segments confidently
# attributed to two distinct speakers (story 862 criteria 7339, 7346).
write_cassette.("two_speakers", [
  remap.(speaker_one_turn, 0, 3_000, "speaker_one"),
  remap.(speaker_two_turn, 3_000, 8_000, "speaker_two")
])

# cross_talk.json — one confident speaker, one genuinely ambiguous/
# overlapping segment that must surface as "Unknown" (criterion 7343).
write_cassette.("cross_talk", [
  remap.(speaker_one_turn, 0, 3_000, "speaker_one"),
  remap.(overlap_turn, 3_000, 8_000, nil)
])

# known_voice.json — reused verbatim (same real embedding) across every
# "*-meeting-with-alex.wav" recording in criteria 7341/7344, so the
# second/third recording's "speaker_one" turn genuinely cosine-matches
# whatever centroid the first recording's speaker_one turn produced.
write_cassette.("known_voice", [
  remap.(speaker_one_turn, 0, 3_000, "speaker_one"),
  remap.(speaker_two_turn, 3_000, 8_000, "speaker_two")
])
