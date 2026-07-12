defmodule EarWitness.Audio.PeakDetector do
  @moduledoc """
  Computes a normalized peak input level from a chunk of raw 16-bit PCM
  audio samples, for live level metering during capture (see
  `EarWitness.Audio.subscribe_levels/1`). Pure and stateless — the
  capture pipeline calls this per buffer and broadcasts the result.
  """

  @doc """
  Returns the peak absolute sample amplitude in `samples`, normalized to
  the `0.0..1.0` range against the full 16-bit signed sample space.
  Empty input has no signal, so it reads as silence (`0.0`).
  """
  @spec peak_level(binary()) :: float()
  def peak_level(<<>>), do: 0.0

  def peak_level(samples) when is_binary(samples) do
    samples
    |> peaks()
    |> Enum.max()
    |> normalize()
  end

  defp peaks(samples) do
    for <<sample::signed-little-16 <- samples>>, do: abs(sample)
  end

  defp normalize(peak), do: min(peak / 32_768, 1.0)
end
