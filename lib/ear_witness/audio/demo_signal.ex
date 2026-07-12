defmodule EarWitness.Audio.DemoSignal do
  @moduledoc """
  Pure signal helpers for the live-hardware audio demo
  (`Mix.Tasks.EarWitness.AudioDemo`): generate test tones, write/read them as
  the same 16kHz mono PCM16 WAVs the capture backends use, and analyse a
  captured WAV with RMS and a single-frequency **Goertzel** detector.

  Everything here is deterministic and I/O-light (only `write_wav/2` and
  `read_wav_samples/1` touch disk), so the demo's PASS/FAIL numbers come from
  ordinary, testable math rather than anything hidden in the NIF. Samples are
  plain integers in the signed-16-bit range; amplitudes and RMS are reported
  normalised to full scale (0.0..1.0) so they read the same regardless of tone
  loudness.
  """

  alias EarWitness.Recordings.WavHeader

  @sample_rate 16_000
  @channels 1
  @bits_per_sample 16
  @full_scale 32_767
  @int16_min -32_768
  @int16_max 32_767

  @doc "The sample rate every demo WAV is generated at (matches the capture backend)."
  @spec sample_rate() :: pos_integer()
  def sample_rate, do: @sample_rate

  @doc """
  Generates a mono sine tone: a list of signed-16-bit samples at
  `#{@sample_rate}`Hz. `amplitude` is 0.0..1.0 of full scale (default 0.6, a
  comfortable, non-clipping level). A short linear fade in/out is applied to
  suppress the click a hard start/stop would add — keeping the tone a clean
  single frequency for the Goertzel check.
  """
  @spec tone(number(), number(), number()) :: [integer()]
  def tone(freq, duration_s, amplitude \\ 0.6) do
    n = round(duration_s * @sample_rate)

    if n <= 0 do
      []
    else
      fade = min(div(n, 4), round(0.005 * @sample_rate))
      amp = amplitude * @full_scale
      w = 2.0 * :math.pi() * freq / @sample_rate

      for i <- 0..(n - 1) do
        env = envelope(i, n, fade)
        trunc(amp * env * :math.sin(w * i))
      end
    end
  end

  defp envelope(_i, _n, fade) when fade <= 0, do: 1.0

  defp envelope(i, n, fade) do
    cond do
      i < fade -> i / fade
      i >= n - fade -> (n - 1 - i) / fade
      true -> 1.0
    end
  end

  @doc "Encodes samples as a little-endian PCM16 binary (clamped to the int16 range)."
  @spec to_binary([integer()]) :: binary()
  def to_binary(samples) do
    for s <- samples, into: <<>>, do: <<clamp(s)::little-signed-16>>
  end

  @doc "Wraps PCM16 samples in a 44-byte RIFF/WAVE header — the exact layout the capture backends emit."
  @spec wav(([integer()] | binary())) :: binary()
  def wav(samples) when is_list(samples), do: wav(to_binary(samples))

  def wav(data) when is_binary(data) do
    data_size = byte_size(data)
    block_align = @channels * div(@bits_per_sample, 8)
    byte_rate = @sample_rate * block_align

    <<"RIFF", 36 + data_size::little-32, "WAVE", "fmt ", 16::little-32, 1::little-16,
      @channels::little-16, @sample_rate::little-32, byte_rate::little-32, block_align::little-16,
      @bits_per_sample::little-16, "data", data_size::little-32, data::binary>>
  end

  @doc "Writes samples to `path` as a 16kHz mono PCM16 WAV."
  @spec write_wav(Path.t(), ([integer()] | binary())) :: :ok
  def write_wav(path, samples), do: File.write!(path, wav(samples))

  @doc "Reads a WAV's PCM payload back into a list of signed-16-bit samples (empty on a non-WAV)."
  @spec read_wav_samples(Path.t()) :: [integer()]
  def read_wav_samples(path) do
    case WavHeader.data_bytes(File.read!(path)) do
      {:ok, data} -> for <<s::little-signed-16 <- data>>, do: s
      {:error, _} -> []
    end
  end

  @doc "Root-mean-square level of the samples, normalised to full scale (0.0..1.0)."
  @spec rms([integer()]) :: float()
  def rms([]), do: 0.0

  def rms(samples) do
    {sum_sq, n} =
      Enum.reduce(samples, {0.0, 0}, fn s, {acc, count} ->
        x = s / (@full_scale + 1)
        {acc + x * x, count + 1}
      end)

    :math.sqrt(sum_sq / n)
  end

  @doc """
  Goertzel single-bin power at `freq` (normalised sample units). This is the
  squared magnitude of the DFT coefficient for exactly `freq`, computed in one
  pass without a full FFT — the classic way to ask "how much energy sits at
  this one frequency?".
  """
  @spec goertzel_power([integer()], number(), pos_integer()) :: float()
  def goertzel_power(samples, freq, sample_rate \\ @sample_rate) do
    omega = 2.0 * :math.pi() * freq / sample_rate
    coeff = 2.0 * :math.cos(omega)

    {s_prev, s_prev2} =
      Enum.reduce(samples, {0.0, 0.0}, fn x, {sp, sp2} ->
        s = x / (@full_scale + 1) + coeff * sp - sp2
        {s, sp}
      end)

    s_prev * s_prev + s_prev2 * s_prev2 - coeff * s_prev * s_prev2
  end

  @doc """
  Goertzel amplitude estimate at `freq`, normalised to full scale. For a pure
  tone sitting at `freq` this returns roughly its amplitude (so a 0.6-full-scale
  440Hz tone reads ~0.6 at 440 and ~0 at an off-target frequency), which makes
  the dominance ratio in the tap test directly interpretable.
  """
  @spec goertzel_amplitude([integer()], number(), pos_integer()) :: float()
  def goertzel_amplitude(samples, freq, sample_rate \\ @sample_rate) do
    n = length(samples)

    if n == 0 do
      0.0
    else
      2.0 * :math.sqrt(max(goertzel_power(samples, freq, sample_rate), 0.0)) / n
    end
  end

  defp clamp(s) when s < @int16_min, do: @int16_min
  defp clamp(s) when s > @int16_max, do: @int16_max
  defp clamp(s), do: s
end
