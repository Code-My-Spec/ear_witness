defmodule EarWitness.Speakers.Diarizer.Models do
  @moduledoc """
  Loads and caches the ONNX models `EarWitness.Speakers.Diarizer.Onnx`
  runs on-device, so a busy transcript editor doesn't reload them from
  disk on every diarization pass.

  - `segmentation-3.0.onnx` — pyannote's `segmentation-3.0`, local
    (up to 3 concurrent) speaker activation per audio frame, powerset
    encoded (7 classes: non-speech, A, B, C, A+B, A+C, B+C).
  - `voxceleb_resnet34_LM.onnx` — WeSpeaker's ResNet34 speaker-embedding
    model (large-margin fine-tuned), trained on VoxCeleb2. Fetched from
    https://huggingface.co/Wespeaker/wespeaker-voxceleb-resnet34-LM/blob/main/voxceleb_resnet34_LM.onnx
    (sha256 7bb2f06e9df17cdf1ef14ee8a15ab08ed28e8d0ef5054ee135741560df2ec068),
    same dev-time provenance as the bundled whisper/silero/segmentation
    models — see `EarWitness.Models` for the user-facing model catalog;
    this one is small enough to ship rather than download at runtime.
  """

  @segmentation_key {__MODULE__, :segmentation}
  @embedding_key {__MODULE__, :embedding}

  @doc "The loaded (and cached) speaker-segmentation model."
  @spec segmentation() :: Ortex.Model.t()
  def segmentation, do: load_once(@segmentation_key, "segmentation-3.0.onnx")

  @doc "The loaded (and cached) voice-embedding model."
  @spec embedding() :: Ortex.Model.t()
  def embedding, do: load_once(@embedding_key, "voxceleb_resnet34_LM.onnx")

  defp load_once(key, filename) do
    case :persistent_term.get(key, nil) do
      nil ->
        model = Ortex.load(Path.join([:code.priv_dir(:ear_witness), "models", filename]))
        :persistent_term.put(key, model)
        model

      model ->
        model
    end
  end
end
