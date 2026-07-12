defmodule EarWitness.Audio.Tap do
  @moduledoc """
  System audio tap availability. Real macOS Core Audio process tap /
  Windows WASAPI loopback discovery is not wired up yet (see the
  membrane-audio-capture ADR) — outside the `:fixture` seam this honestly
  reports "not set up" rather than pretending a tap exists.

  `EarWitnessSpex.Fixtures.simulate_tap_not_installed/0` overrides the
  fixture seam's default (installed) to simulate the not-set-up path.
  """

  @spec installed?() :: boolean()
  def installed? do
    case Application.get_env(:ear_witness, :tap_installed_override) do
      nil -> Application.get_env(:ear_witness, :capture_source) == :fixture
      override -> override
    end
  end
end
