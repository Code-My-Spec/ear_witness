defmodule EarWitnessTest.RecordedTranscriptionEngine do
  @moduledoc """
  Replays recorded whisper.cpp responses at the transcription-engine seam.

  This is NOT a hand-written fake: the cassettes under
  `test/fixtures/transcription_cassettes/` are captured from the real NIF
  running the real model on the repo's fixture audio. Re-record when
  whisper.cpp or the bundled model changes:

      mix run --no-start -e '
        json = EarWitness.Transcribe.transcribe_files(["test/fixtures/vad-f32.raw"])
        File.write!("test/fixtures/transcription_cassettes/vad-f32.json", json)'

  Engine contract (the future `EarWitness.Transcription.Engine` implements
  the same): `transcribe(audio_path, opts) :: {:ok, results} | {:error, term}`
  where `results` is the decoded whisper JSON (a list of documents each
  carrying a "transcription" list of segments with "text" and "timestamps").
  The implementation selects its engine via
  `Application.get_env(:ear_witness, :transcription_engine)` — test env
  points here (config/test.exs).
  """

  @cassette_dir "test/fixtures/transcription_cassettes"
  @default_cassette "vad-f32"

  def transcribe(_audio_path, opts \\ []) do
    cassette = Keyword.get(opts, :cassette, @default_cassette)

    with {:ok, json} <- File.read(Path.join(@cassette_dir, cassette <> ".json")),
         {:ok, decoded} <- Jason.decode(json) do
      {:ok, decoded}
    end
  end
end
