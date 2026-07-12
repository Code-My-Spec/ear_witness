defmodule EarWitness.Speakers.Diarizer.Pcm do
  @moduledoc """
  Decodes a WAV file's declared PCM samples into a mono, 16kHz, f32
  `Nx.Tensor` — the format every model in
  `EarWitness.Speakers.Diarizer.Onnx` expects. Stereo is down-mixed by
  averaging channels; anything not already 16kHz is linearly
  resampled (simple, not broadcast-quality, but honest — no resampler
  dependency is part of this project, see the membrane-audio-capture
  ADR and `EarWitness.Recordings.Importer`).
  """

  alias EarWitness.Recordings.WavHeader

  @target_sample_rate 16_000

  @doc "Reads and decodes a WAV file at `path` into mono 16kHz f32 samples."
  @spec read(Path.t()) :: {:ok, Nx.Tensor.t()} | {:error, :invalid_audio_file}
  def read(path) do
    with {:ok, bytes} <- File.read(path),
         {:ok, header} <- WavHeader.parse(bytes),
         {:ok, data} <- WavHeader.data_bytes(bytes),
         {:ok, samples} <- decode(data, header) do
      {:ok, resample(samples, header.sample_rate, @target_sample_rate)}
    else
      {:error, _reason} -> {:error, :invalid_audio_file}
      :error -> {:error, :invalid_audio_file}
    end
  end

  defp decode(data, %{bits_per_sample: 16, channels: 1}) do
    {:ok, data |> Nx.from_binary(:s16) |> Nx.as_type(:f32) |> Nx.divide(32_768.0)}
  end

  defp decode(data, %{bits_per_sample: 16, channels: channels}) when channels > 1 do
    mono =
      data
      |> Nx.from_binary(:s16)
      |> Nx.as_type(:f32)
      |> Nx.divide(32_768.0)
      |> Nx.reshape({:auto, channels})
      |> Nx.mean(axes: [1])

    {:ok, mono}
  end

  defp decode(data, %{bits_per_sample: 8, channels: 1}) do
    {:ok, data |> Nx.from_binary(:u8) |> Nx.as_type(:f32) |> Nx.subtract(128) |> Nx.divide(128.0)}
  end

  defp decode(_data, _header), do: {:error, :unsupported_pcm_format}

  defp resample(samples, rate, rate), do: samples

  # Fully vectorized linear interpolation (`Nx.take` gather, no
  # per-sample Elixir loop) — real recordings can be long enough that a
  # scalar-at-a-time implementation would be impractically slow.
  defp resample(samples, from_rate, to_rate) do
    source_length = Nx.size(samples)
    target_length = max(round(source_length * to_rate / from_rate), 1)
    ratio = from_rate / to_rate

    positions = Nx.iota({target_length}) |> Nx.as_type(:f32) |> Nx.multiply(ratio)
    lower = positions |> Nx.floor() |> Nx.as_type(:s64) |> Nx.clip(0, source_length - 1)
    upper = lower |> Nx.add(1) |> Nx.clip(0, source_length - 1)
    fraction = Nx.subtract(positions, Nx.as_type(lower, :f32))

    lower_values = Nx.take(samples, lower)
    upper_values = Nx.take(samples, upper)

    Nx.add(lower_values, Nx.multiply(Nx.subtract(upper_values, lower_values), fraction))
  end
end
