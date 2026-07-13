defmodule EarWitness.Audio.Pipeline do
  @moduledoc """
  Captures live audio for `EarWitness.Audio.start_capture/1` /
  `stop_capture/1`. The `:fixture` seam (`config :ear_witness,
  :capture_source`) substitutes canned WAV bytes for real device I/O, so
  specs can drive the real Record/Stop UI on any machine.

  Real capture goes through `EarWitness.Audio.Miniaudio`, a miniaudio C
  NIF (see the miniaudio-capture ADR): microphone capture works on every
  platform; system-audio-tap (loopback) capture works on Windows and Linux
  (miniaudio) and on macOS 14.4+ (a native Core Audio process tap behind the
  same NIF — see the macos-system-audio-tap ADR). `EarWitness.Audio.Tap`
  gates it and reports it unavailable only on macOS below 14.4.
  """

  alias EarWitness.Audio.{Captures, Miniaudio, Tap}

  @fixture_sample_rate 16_000
  @fixture_num_samples 8_000
  # Must match EarWitness.Audio.Miniaudio's capture sample rate.
  @capture_sample_rate 16_000

  @doc "Lists available microphone input devices — fixture devices in the `:fixture` test seam."
  @spec input_devices() :: [map()]
  def input_devices do
    case Application.get_env(:ear_witness, :capture_devices_override) do
      nil -> default_input_devices()
      override -> override
    end
  end

  defp default_input_devices do
    case Application.get_env(:ear_witness, :capture_source) do
      source when source in [:fixture, :fixture_live] ->
        [%{id: :fixture_microphone, name: "Fixture Microphone"}]

      _real ->
        Miniaudio.list_devices()
        |> Enum.filter(&(&1.max_input_channels > 0))
        # The NIF's enumeration order isn't guaranteed to put the default
        # device first on every backend; `capture/2` always picks the head
        # of this list, so pin the default device there explicitly.
        |> Enum.sort_by(&(!&1.is_default))
    end
  end

  @doc "Starts capturing `source` to `path`, returning `{:ok, ref, channels}` or an error."
  @spec capture(:microphone | :system_audio_tap, Path.t()) ::
          {:ok, reference(), [:microphone | :system_audio]}
          | {:error, :no_input_device | :source_unavailable}
  def capture(:microphone, path) do
    case input_devices() do
      [] -> {:error, :no_input_device}
      _devices -> start(:microphone, path)
    end
  end

  def capture(:system_audio_tap, path) do
    if Tap.installed?() do
      start(:system_audio_tap, path)
    else
      {:error, :source_unavailable}
    end
  end

  @doc """
  Returns `{:ok, handle}` with the native capture handle for a running real
  capture `ref`, or `:error` for an unknown `ref` or a `:fixture` capture
  (which has no device handle). Backs `EarWitness.Audio.capture_handle/1`.
  """
  @spec capture_handle(reference()) :: {:ok, term()} | :error
  def capture_handle(ref) do
    case Captures.get(ref) do
      %{kind: :real, capture_handle: handle} -> {:ok, handle}
      %{kind: :test, capture_handle: handle} -> {:ok, handle}
      _ -> :error
    end
  end

  @doc "Stops the capture identified by `ref`, returning its channels and output path."
  @spec stop(reference()) :: {:ok, %{channels: [atom()], path: Path.t()}} | {:error, :not_found}
  def stop(ref) do
    case Captures.pop(ref) do
      nil ->
        {:error, :not_found}

      %{kind: :real, capture_handle: handle, path: path, channels: channels} ->
        # Errors here are surfaced only as a possibly-incomplete file —
        # finalize_wav/1 and downstream WavHeader.parse/1 catch that.
        _ = Miniaudio.stop_capture(handle)
        finalize_wav(path)
        {:ok, %{channels: channels, path: path}}

      %{kind: :fixture, path: path, channels: channels} ->
        {:ok, %{channels: channels, path: path}}

      # Live-transcription spec seam (see start_test/2) — its WAV was written at
      # start and there is no device to stop, so just report the finished file.
      %{kind: :test, path: path, channels: channels} ->
        {:ok, %{channels: channels, path: path}}
    end
  end

  # EarWitness.Audio.Miniaudio.stop_capture/1 already writes a complete
  # RIFF/WAVE file, so this is normally a no-op — kept as a defensive
  # safety net (story-860 QA originally found the prior Membrane raw-sample
  # sink needed this finalize step; a NIF write failure or empty capture
  # leaving a non-RIFF or missing file falls through here too, and
  # WavHeader.parse/1 catches whatever finalize_wav/1 can't fix).
  defp finalize_wav(path) do
    case File.read(path) do
      {:ok, <<head::binary-size(4), _rest::binary>> = raw} when head != "RIFF" ->
        pcm16 = f32le_to_s16le(raw)
        File.write!(path, pcm16_wav(pcm16, @capture_sample_rate))

      _already_wav_or_unreadable ->
        :ok
    end
  end

  defp f32le_to_s16le(raw) do
    for <<sample::float-little-32 <- raw>>, into: <<>> do
      clamped = min(max(sample, -1.0), 1.0)
      <<round(clamped * 32_767)::little-signed-16>>
    end
  end

  defp pcm16_wav(data, sample_rate) do
    channels = 1
    bits_per_sample = 16
    block_align = channels * div(bits_per_sample, 8)
    byte_rate = sample_rate * block_align
    data_size = byte_size(data)

    <<
      "RIFF",
      36 + data_size::little-32,
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

  defp start(source, path) do
    case Application.get_env(:ear_witness, :capture_source) do
      :fixture -> start_fixture(source, path)
      :fixture_live -> start_test(source, path)
      _real -> start_real(source, path)
    end
  end

  # Test-only capture backend for the live-transcription spec seam (story 872).
  # Like `:fixture` it writes canned WAV bytes instead of touching a device, but
  # it ALSO hands back an opaque handle so `EarWitness.Audio.capture_handle/1`
  # reports it as a real, live-transcribable capture — that's what makes
  # `Recordings.start_live_capture/0` actually start the `LiveTranscriber` under
  # test (a plain `:fixture` capture has no handle and is skipped). The drain
  # side is supplied by the configured `:capture_reader`
  # (`EarWitnessTest.FakeCaptureReader`), which a spec pushes PCM into; `stop/1`
  # below finalizes it without any NIF call. Only reachable when
  # `:capture_source` is `:fixture_live`, which production never sets.
  defp start_test(source, path) do
    File.write!(path, fixture_wav())
    channels = channels_for(source)
    ref = make_ref()
    Captures.put(ref, %{kind: :test, capture_handle: make_ref(), path: path, channels: channels})
    {:ok, ref, channels}
  end

  defp start_fixture(source, path) do
    File.write!(path, fixture_wav())
    channels = channels_for(source)
    ref = make_ref()
    Captures.put(ref, %{kind: :fixture, path: path, channels: channels})
    {:ok, ref, channels}
  end

  defp start_real(:microphone, path) do
    [device | _] = input_devices()

    case Miniaudio.start_capture(device_index(device), path) do
      {:ok, handle} ->
        ref = make_ref()

        Captures.put(ref, %{
          kind: :real,
          capture_handle: handle,
          path: path,
          channels: [:microphone]
        })

        {:ok, ref, [:microphone]}

      {:error, _reason} ->
        {:error, :no_input_device}
    end
  end

  # System-audio-tap capture is loopback-only for now (Windows WASAPI
  # loopback, Linux PulseAudio/PipeWire monitor source, macOS Core Audio
  # process tap — see the miniaudio-capture and macos-system-audio-tap ADRs);
  # it does not additionally mix in the microphone, unlike the `:fixture`
  # seam's simulated `[:microphone, :system_audio]` double channel.
  defp start_real(:system_audio_tap, path) do
    case Miniaudio.start_loopback_capture(path) do
      {:ok, handle} ->
        ref = make_ref()

        Captures.put(ref, %{
          kind: :real,
          capture_handle: handle,
          path: path,
          channels: [:system_audio]
        })

        {:ok, ref, [:system_audio]}

      {:error, _reason} ->
        {:error, :source_unavailable}
    end
  end

  defp device_index(%{id: id}) when is_integer(id) and id >= 0, do: id
  defp device_index(_device), do: -1

  defp channels_for(:microphone), do: [:microphone]
  defp channels_for(:system_audio_tap), do: [:microphone, :system_audio]

  defp fixture_wav do
    channels = 1
    bits_per_sample = 16
    block_align = channels * div(bits_per_sample, 8)
    byte_rate = @fixture_sample_rate * block_align
    data = :binary.copy(<<0::little-16>>, @fixture_num_samples)
    data_size = byte_size(data)

    <<
      "RIFF",
      36 + data_size::little-32,
      "WAVE",
      "fmt ",
      16::little-32,
      1::little-16,
      channels::little-16,
      @fixture_sample_rate::little-32,
      byte_rate::little-32,
      block_align::little-16,
      bits_per_sample::little-16,
      "data",
      data_size::little-32
    >> <> data
  end
end
