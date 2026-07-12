defmodule EarWitness.Speakers.Diarizer.Embedding do
  @moduledoc """
  Extracts a 256-dim, L2-normalized voice-signature vector for a span of
  16kHz mono f32 audio, via `EarWitness.Speakers.Diarizer.Fbank` feeding
  the bundled WeSpeaker ResNet34 ONNX model
  (`EarWitness.Speakers.Diarizer.Models.embedding/0`). L2-normalizing
  means cosine similarity between two speakers' vectors is just their
  dot product — see `EarWitness.Speakers.resolve_speaker/1`.
  """

  alias EarWitness.Speakers.Diarizer.{Fbank, Models}

  # Shorter than one fbank frame can't produce any feature at all.
  @min_samples 400

  @doc "Extracts a voice-signature embedding, or `nil` when `samples` is too short to say anything about."
  @spec extract(Nx.Tensor.t()) :: [float()] | nil
  def extract(samples) do
    if Nx.size(samples) < @min_samples do
      nil
    else
      samples |> Fbank.extract() |> embed()
    end
  end

  defp embed(feats) do
    case Nx.shape(feats) do
      {0, _bins} ->
        nil

      {num_frames, bins} ->
        input = feats |> Nx.reshape({1, num_frames, bins}) |> Nx.as_type(:f32)
        {embedding} = Ortex.run(Models.embedding(), {input})

        embedding
        |> Nx.backend_transfer()
        |> Nx.reshape({256})
        |> normalize()
        |> Nx.to_flat_list()
    end
  end

  defp normalize(vector) do
    norm = vector |> Nx.pow(2) |> Nx.sum() |> Nx.sqrt() |> Nx.to_number()
    if norm > 0.0, do: Nx.divide(vector, norm), else: vector
  end
end
