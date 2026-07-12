defmodule EarWitness.Audio.Miniaudio do
  @moduledoc """
  Thin wrapper around the miniaudio capture NIF
  (`c_src/ear_witness/audio_capture.cpp`, vendoring the single-header
  `c_src/miniaudio.h`, built to `priv/audio_capture_nif.so`) — the real
  (non-fixture) capture backend for `EarWitness.Audio.Pipeline`. See the
  miniaudio-capture ADR.

  Microphone capture works on every platform miniaudio supports (macOS
  Core Audio, Windows WASAPI, Linux ALSA/PulseAudio/PipeWire). System-audio
  loopback capture is Windows-only (native WASAPI loopback) and
  Linux-only (a PulseAudio/PipeWire "monitor" source opened as an ordinary
  capture device) — `loopback_available?/0` honestly reports `false` on
  macOS, which has no miniaudio loopback backend
  (mackron/miniaudio#875) and needs the separate Core Audio process-tap
  module described in the macos-system-audio-tap ADR; this module never
  fakes availability.

  Every capture is resampled/converted by miniaudio to 16kHz mono PCM16
  regardless of the source device's native format, matching what
  `EarWitness.Recordings.WavHeader.parse/1` and the transcription engine
  expect. `stop_capture/1` writes the finished WAV file to the path given
  to `start_capture/2` or `start_loopback_capture/1`.
  """

  @on_load :load_nif

  @doc false
  def load_nif do
    path = :filename.join(:code.priv_dir(:ear_witness), ~c"audio_capture_nif")

    # Tolerate a missing NIF so the module (and app) still load on
    # platforms/dev machines where the capture NIF hasn't been built yet —
    # mirrors EarWitness.Transcribe's convention. Every exported function
    # below then exits with :nif_library_not_loaded only if it's actually
    # invoked.
    case :erlang.load_nif(path, 0) do
      :ok -> :ok
      {:error, _} -> :ok
    end
  end

  @doc "Lists capture- and playback-capable audio devices known to the system."
  @spec list_devices() :: [map()]
  def list_devices, do: exit(:nif_library_not_loaded)

  @doc """
  Starts recording 16kHz mono PCM16 from the capture device at `device_index`
  (as returned by `list_devices/0`) to `path`. Falls back to the platform
  default capture device if `device_index` is out of range.
  """
  @spec start_capture(non_neg_integer(), Path.t()) :: {:ok, term()} | {:error, atom()}
  def start_capture(_device_index, _path), do: exit(:nif_library_not_loaded)

  @doc """
  Starts recording system-output audio (loopback) to `path`. Only
  available where `loopback_available?/0` returns `true` (Windows, and
  Linux with a PulseAudio/PipeWire monitor source) — returns
  `{:error, :source_unavailable}` everywhere else, including macOS.
  """
  @spec start_loopback_capture(Path.t()) :: {:ok, term()} | {:error, atom()}
  def start_loopback_capture(_path), do: exit(:nif_library_not_loaded)

  @doc """
  Stops a capture started by `start_capture/2` or
  `start_loopback_capture/1`, finalizing its WAV file at the path given to
  the start call.
  """
  @spec stop_capture(term()) :: :ok | {:error, atom()}
  def stop_capture(_handle), do: exit(:nif_library_not_loaded)

  @doc "Whether system-output loopback capture is available on this machine."
  @spec loopback_available?() :: boolean()
  def loopback_available?, do: exit(:nif_library_not_loaded)
end
