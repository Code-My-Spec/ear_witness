defmodule EarWitnessSpex.WavFixture do
  @moduledoc """
  In-memory WAV byte construction for BDD specs.

  Building fixture audio purely in memory (never touching `File`) keeps
  BDD specs inside the sanctioned LiveView surface — see
  `.code_my_spec/knowledge/bdd/spex/boundaries.md` and the local Credo
  check `EARWIT0001`, which denies `File`/`Port` in `_spex.exs` files.
  """

  @doc """
  Builds a minimal, valid mono 16-bit PCM WAV file as an in-memory binary.

  `:sample_rate` and `:num_samples` control the declared duration
  (`num_samples / sample_rate` seconds).
  """
  def build(opts \\ []) do
    sample_rate = Keyword.get(opts, :sample_rate, 16_000)
    num_samples = Keyword.get(opts, :num_samples, 1_600)
    channels = 1
    bits_per_sample = 16
    block_align = channels * div(bits_per_sample, 8)
    byte_rate = sample_rate * block_align

    data = :binary.copy(<<0::little-16>>, num_samples)
    data_size = byte_size(data)
    riff_size = 36 + data_size

    <<
      "RIFF",
      riff_size::little-32,
      "WAVE",
      "fmt ",
      16::little-32,
      1::little-16,
      channels::little-16,
      sample_rate::little-32,
      byte_rate::little-32,
      block_align::little-16,
      bits_per_sample::little-16,
      "data",
      data_size::little-32
    >> <> data
  end

  @doc "A short, ordinary WAV file — the common case for import/transcribe specs."
  def short, do: build(sample_rate: 16_000, num_samples: 1_600)

  @doc """
  A WAV file whose header honestly declares a three-hour duration
  (`num_samples / sample_rate == 3 * 60 * 60` seconds) while staying a few
  KB in memory, via a deliberately low sample rate. The transcription
  engine itself runs behind a canned test double in specs (see
  `.code_my_spec/knowledge/bdd/spex/index.md`), so nothing here depends on
  real multi-hour audio content — only on the recording carrying an
  honest, long declared duration end to end through import and display.
  """
  def three_hours, do: build(sample_rate: 2, num_samples: 3 * 60 * 60 * 2)

  @doc "Bytes that are not a valid WAV file at all — no RIFF/WAVE header."
  def corrupt, do: :binary.copy(<<0xDE, 0xAD, 0xBE, 0xEF>>, 32)
end
