defmodule EarWitness.Speakers.Diarizer.Fbank do
  @moduledoc """
  80-bin log-mel filterbank features for the WeSpeaker voice-embedding
  model (`EarWitness.Speakers.Diarizer.Embedding`), extracted from
  16kHz mono f32 PCM samples: 25ms/10ms frame/shift, pre-emphasis,
  Hamming window, magnitude FFT (`Nx.fft/2`), an 80-bin mel filterbank,
  log compression, and per-utterance mean normalization.

  A from-scratch implementation — this project bundles no
  Python/Kaldi/torchaudio to lean on for feature extraction — so it is
  not guaranteed bit-exact with the Kaldi `fbank` recipe the model was
  trained against. That's an accepted honest limitation rather than a
  correctness bug: every embedding this app ever compares was extracted
  by this same pipeline (see `EarWitness.Speakers.Diarizer.Onnx`), so
  internal consistency (the same voice always yields a near-identical
  vector) is what cross-recording matching depends on, not exact parity
  with the original training recipe.
  """

  @sample_rate 16_000
  @frame_length trunc(@sample_rate * 0.025)
  @frame_shift trunc(@sample_rate * 0.010)
  @n_fft 512
  @num_mel_bins 80
  @pre_emphasis 0.97
  @mel_filterbank_key {__MODULE__, :mel_filterbank}

  @doc "Extracts `{num_frames, 80}` log-mel features from a 1-D f32 sample tensor."
  @spec extract(Nx.Tensor.t()) :: Nx.Tensor.t()
  def extract(samples) do
    samples = Nx.backend_transfer(samples)

    case frame_signal(samples) do
      {:empty, frames} ->
        frames

      {:ok, frames} ->
        frames
        |> pre_emphasize()
        |> apply_window()
        |> power_spectrum()
        |> mel_energies()
        |> log_compress()
        |> mean_normalize()
    end
  end

  defp frame_signal(samples) do
    n = Nx.size(samples)
    num_frames = if n < @frame_length, do: 0, else: div(n - @frame_length, @frame_shift) + 1

    if num_frames == 0 do
      {:empty, Nx.broadcast(0.0, {0, @num_mel_bins})}
    else
      frames =
        0..(num_frames - 1)
        |> Enum.map(fn i -> Nx.slice(samples, [i * @frame_shift], [@frame_length]) end)
        |> Nx.stack()

      {:ok, frames}
    end
  end

  defp pre_emphasize(frames) do
    len = @frame_length
    first_column = Nx.slice_along_axis(frames, 0, 1, axis: 1)
    leading = Nx.slice_along_axis(frames, 0, len - 1, axis: 1)
    previous = Nx.concatenate([first_column, leading], axis: 1)
    Nx.subtract(frames, Nx.multiply(previous, @pre_emphasis))
  end

  defp apply_window(frames), do: Nx.multiply(frames, hamming_window())

  defp hamming_window do
    0..(@frame_length - 1)
    |> Enum.map(fn n -> 0.54 - 0.46 * :math.cos(2 * :math.pi() * n / (@frame_length - 1)) end)
    |> Nx.tensor()
  end

  defp power_spectrum(frames) do
    half = div(@n_fft, 2) + 1

    frames
    |> Nx.fft(length: @n_fft)
    |> Nx.abs()
    |> Nx.slice_along_axis(0, half, axis: 1)
    |> Nx.pow(2)
  end

  defp mel_energies(power), do: Nx.dot(power, Nx.transpose(mel_filterbank_matrix()))

  defp log_compress(mel), do: Nx.log(Nx.max(mel, 1.0e-10))

  defp mean_normalize(feats) do
    mean = Nx.mean(feats, axes: [0], keep_axes: true)
    Nx.subtract(feats, mean)
  end

  defp mel_filterbank_matrix do
    case :persistent_term.get(@mel_filterbank_key, nil) do
      nil ->
        matrix = build_mel_filterbank()
        :persistent_term.put(@mel_filterbank_key, matrix)
        matrix

      matrix ->
        matrix
    end
  end

  defp build_mel_filterbank do
    half = div(@n_fft, 2) + 1
    low_mel = hz_to_mel(20.0)
    high_mel = hz_to_mel(@sample_rate / 2)
    step = (high_mel - low_mel) / (@num_mel_bins + 1)

    bin_points =
      for i <- 0..(@num_mel_bins + 1) do
        (low_mel + i * step) |> mel_to_hz() |> then(&(&1 * @n_fft / @sample_rate))
      end
      |> List.to_tuple()

    rows =
      for m <- 1..@num_mel_bins do
        left = elem(bin_points, m - 1)
        center = elem(bin_points, m)
        right = elem(bin_points, m + 1)

        for k <- 0..(half - 1) do
          triangle_weight(k, left, center, right)
        end
      end

    Nx.tensor(rows)
  end

  defp triangle_weight(k, left, _center, right) when k < left or k > right, do: 0.0

  defp triangle_weight(k, left, center, _right) when k <= center,
    do: (k - left) / max(center - left, 1.0e-10)

  defp triangle_weight(k, _left, center, right), do: (right - k) / max(right - center, 1.0e-10)

  defp hz_to_mel(hz), do: 2595.0 * :math.log10(1 + hz / 700.0)
  defp mel_to_hz(mel), do: 700.0 * (:math.pow(10, mel / 2595.0) - 1)
end
