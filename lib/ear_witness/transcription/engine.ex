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
    # Every whisper run loads a full model; concurrent runs (batch imports ×
    # live capture × legacy queue) can exhaust the machine, so all of them
    # serialize through the gate.
    EarWitness.Transcription.Gate.run(fn ->
      [audio_path]
      |> EarWitness.Transcribe.transcribe_files(active_model_path())
      |> to_string()
      |> Jason.decode()
    end)
  end

  # Resolves the active model's file path for the NIF. Falls back to an
  # empty string when nothing is active or the selection isn't downloaded
  # yet — the NIF then loads the bundled base model. Passing the path (not a
  # hardcoded default) is what makes the Settings model selection actually
  # take effect for transcription.
  defp active_model_path do
    with %{id: id} <- EarWitness.Models.get_active_model(),
         {:ok, path} <- EarWitness.Models.model_path(id) do
      path
    else
      _ -> ""
    end
  end
end
