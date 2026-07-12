defmodule EarWitness.Audio.Pipeline do
  @moduledoc """
  Captures live audio for `EarWitness.Audio.start_capture/1` /
  `stop_capture/1`. The `:fixture` seam (`config :ear_witness,
  :capture_source`) substitutes canned WAV bytes for real device I/O, so
  specs can drive the real Record/Stop UI on any machine.

  Real microphone capture wraps `Membrane.PortAudio.Source` directly (see
  `EarWitness.Audio.Pipeline.Microphone`). Real system-audio-tap capture is
  not implemented yet — no Core Audio / WASAPI integration exists (see the
  membrane-audio-capture ADR); `EarWitness.Audio.Tap` reports it
  unavailable outside the fixture seam.
  """

  alias EarWitness.Audio.{Captures, Tap}

  @fixture_sample_rate 16_000
  @fixture_num_samples 8_000
  # Must match Pipeline.Microphone's PortAudio source config.
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
      :fixture ->
        [%{id: :fixture_microphone, name: "Fixture Microphone"}]

      _real ->
        Membrane.PortAudio.list_devices()
        |> Enum.filter(&(&1.max_input_channels > 0))
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

  @doc "Stops the capture identified by `ref`, returning its channels and output path."
  @spec stop(reference()) :: {:ok, %{channels: [atom()], path: Path.t()}} | {:error, :not_found}
  def stop(ref) do
    case Captures.pop(ref) do
      nil ->
        {:error, :not_found}

      %{kind: :real, pipeline_pid: pid, path: path, channels: channels} ->
        Membrane.Pipeline.terminate(pid)
        finalize_wav(path)
        {:ok, %{channels: channels, path: path}}

      %{kind: :fixture, path: path, channels: channels} ->
        {:ok, %{channels: channels, path: path}}
    end
  end

  # Membrane.File.Sink writes the PortAudio source's raw f32le samples with
  # no container — downstream (WavHeader.parse, the whisper engine, import
  # normalization) all expect a real PCM16 WAV, so finalize the capture into
  # one. Found by story-860 QA against the real microphone path (the
  # :fixture seam already produced valid WAV, which is why no spec caught
  # it). Skips files that already carry a RIFF header.
  defp finalize_wav(path) do
    with {:ok, <<head::binary-size(4), _rest::binary>> = raw} when head != "RIFF" <-
           File.read(path) do
      pcm16 = f32le_to_s16le(raw)
      File.write!(path, pcm16_wav(pcm16, @capture_sample_rate))
    else
      _ -> :ok
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
      _real -> start_real(source, path)
    end
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

    {:ok, _supervisor_pid, pipeline_pid} =
      Membrane.Pipeline.start_link(EarWitness.Audio.Pipeline.Microphone,
        device_id: device.id,
        path: path
      )

    ref = make_ref()

    Captures.put(ref, %{
      kind: :real,
      pipeline_pid: pipeline_pid,
      path: path,
      channels: [:microphone]
    })

    {:ok, ref, [:microphone]}
  end

  defp start_real(:system_audio_tap, _path), do: {:error, :source_unavailable}

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
