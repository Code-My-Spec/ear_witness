defmodule EarWitness.Audio.VirtualMic do
  @moduledoc """
  The macOS virtual microphone seam — a virtual audio INPUT device that
  meeting apps (Zoom/Teams/Meet) can select as their microphone, and that
  EarWitness feeds by playing audio into the device's OUTPUT side (the
  "loopback trick": the driver internally wires output → input, so whatever
  EarWitness plays out becomes what the meeting app hears in). See
  `native/vmic-macos/README.md` for the driver, install steps, and the
  signing/distribution reality.

  This is the injection point story 871 uses to land a recording notice on
  the user's outgoing voice channel: `feed/1` / `play_notice/1` play a WAV
  into the virtual device so remote participants hear it live.

  The virtual device appears in `EarWitness.Audio.Miniaudio.list_devices/0`
  as BOTH a capture device (what the meeting app reads) and a playback device
  (what EarWitness writes). `available?/0` checks for its presence by name.

  Nothing here fakes availability: with the driver uninstalled, `available?/0`
  returns `false` and `feed/1` returns `{:error, :device_not_found}`.
  """

  alias EarWitness.Audio.Miniaudio

  # The device/product name baked into the driver build (kDevice_Name in
  # native/vmic-macos/build.sh). Matched as a case-insensitive substring so a
  # channel-count suffix or minor rename won't break detection.
  @device_name "EarWitness Microphone"

  @doc "The virtual microphone's device name, as it appears to the OS."
  @spec device_name() :: String.t()
  def device_name, do: @device_name

  @doc """
  Whether the "EarWitness Microphone" virtual device is installed and visible
  to the audio system right now.
  """
  @spec available?() :: boolean()
  def available? do
    target = String.downcase(@device_name)

    Miniaudio.list_devices()
    |> Enum.any?(fn device ->
      device
      |> Map.get(:name, "")
      |> String.downcase()
      |> String.contains?(target)
    end)
  end

  @doc """
  Plays `wav_path` into the virtual microphone's output so meeting apps that
  have selected it as their mic hear it live. Returns `:ok`, or
  `{:error, :device_not_found}` when the driver isn't installed.
  """
  @spec feed(Path.t()) :: :ok | {:error, atom()}
  def feed(wav_path), do: Miniaudio.play_wav_to_device(wav_path, @device_name)

  @doc "Alias of `feed/1`, named for the story-871 recording-notice use case."
  @spec play_notice(Path.t()) :: :ok | {:error, atom()}
  def play_notice(wav_path), do: feed(wav_path)
end
