defmodule EarWitness.Transcription.Engine do
  @moduledoc """
  Invokes the bundled whisper.cpp binary (via the `EarWitness.Transcribe`
  NIF) against a normalized audio file and returns its decoded JSON
  output. Selected via the `config :ear_witness, :transcription_engine`
  seam — the test environment points at
  `EarWitnessTest.RecordedTranscriptionEngine` instead, so specs replay
  recorded real output rather than running the NIF.
  """

  @spec transcribe(Path.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def transcribe(audio_path, _opts \\ []) do
    [audio_path]
    |> EarWitness.Transcribe.transcribe_files()
    |> to_string()
    |> Jason.decode()
  end
end
