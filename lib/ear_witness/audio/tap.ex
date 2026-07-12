defmodule EarWitness.Audio.Tap do
  @moduledoc """
  System-audio-tap (loopback) availability. Real capture is Windows
  (native WASAPI loopback) and Linux (PulseAudio/PipeWire monitor source)
  only, via `EarWitness.Audio.Miniaudio.loopback_available?/0` — see the
  miniaudio-capture ADR. macOS has no miniaudio loopback backend
  (mackron/miniaudio#875); system-output capture there needs the separate
  Core Audio process-tap module described in the macos-system-audio-tap
  ADR, which is not implemented yet, so this honestly reports "not
  available" on macOS rather than pretending a tap exists.

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
      :fixture -> true
      _real -> Miniaudio.loopback_available?()
    end
  end
end
