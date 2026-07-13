defmodule EarWitness.Audio.Tap do
  @moduledoc """
  System-audio-tap (loopback) availability. Real capture works on Windows
  (native WASAPI loopback), Linux (PulseAudio/PipeWire monitor source), and
  macOS 14.4+ (a native Core Audio process tap — `c_src/ear_witness/mac_tap.mm`,
  see the macos-system-audio-tap ADR — because miniaudio has no macOS loopback
  backend, mackron/miniaudio#875). Availability is delegated to
  `EarWitness.Audio.Miniaudio.loopback_available?/0` (see the miniaudio-capture
  ADR), which reports `false` on macOS below 14.4 rather than pretending a tap
  exists.

  `EarWitnessSpex.Fixtures.simulate_tap_not_installed/0` overrides the
  fixture seam's default (installed) to simulate the not-set-up path.
  """

  alias EarWitness.Audio.Miniaudio

  @spec installed?() :: boolean()
  def installed? do
    case Application.get_env(:ear_witness, :tap_installed_override) do
      nil -> default_installed?()
      override -> override
    end
  end

  defp default_installed? do
    case Application.get_env(:ear_witness, :capture_source) do
      source when source in [:fixture, :fixture_live] -> true
      _real -> Miniaudio.loopback_available?()
    end
  end
end
