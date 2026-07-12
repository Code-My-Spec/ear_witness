defmodule EarWitnessWeb.TodoLive do
  @moduledoc """
    Main live view of our EarWitness. Just allows adding, removing and checking off
    todo items
  """
  use EarWitnessWeb, :live_view
  alias EarWitness.Audio.Miniaudio
  alias EarWitness.LocalSettings
  alias EarWitness.Transcription.Server

  @impl true

  def mount(_args, _session, socket) do
    LocalSettings.subscribe()
    Server.subscribe()

    devices = EarWitness.Audio.list_devices()
    input_devices = Enum.filter(devices, &(&1.max_input_channels > 0))
    output_devices = Enum.filter(devices, &(&1.max_output_channels > 0))
    input_options = Enum.map(input_devices, &{&1.name, &1.id})
    output_options = Enum.map(output_devices, &{&1.name, &1.id})
    %{input: input, output: output} = LocalSettings.get_local_settings()

    {:ok,
     assign(socket,
       devices: devices,
       input_options: input_options,
       output_options: output_options,
       selected_input: input,
       selected_output: output,
       recording: false,
       capture_handle: nil,
       recordings: get_recordings()
     )}
  end

  @impl true
  def handle_event("select_input", %{"input" => input}, socket) do
    LocalSettings.update_local_settings(%{input: input})

    {:noreply, socket}
  end

  def handle_event("select_output", %{"output" => output}, socket) do
    LocalSettings.update_local_settings(%{output: output})

    {:noreply, socket}
  end

  # The "output" device is accepted for backwards compatibility with the
  # existing form/push payload but unused — this legacy screen has never
  # actually captured system-output audio (the prior Membrane
  # RecordingPipeline ignored it too); real system-audio-tap capture lives
  # behind EarWitness.Audio.Pipeline/RecordingLive.Index instead (see the
  # miniaudio-capture ADR).
  def handle_event("record", %{"input" => input}, socket) do
    file_name = "#{System.system_time(:second)}.wav"
    path = Path.join(EarWitness.recordings_dir(), file_name)

    case Miniaudio.start_capture(device_index(input), path) do
      {:ok, handle} ->
        {:noreply,
         assign(socket,
           capture_handle: handle,
           recordings: [file_name | socket.assigns.recordings]
         )}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  def handle_event("stop", _, %{assigns: %{capture_handle: nil}} = socket), do: {:noreply, socket}

  def handle_event("stop", _, %{assigns: %{capture_handle: handle}} = socket) do
    Miniaudio.stop_capture(handle)

    {:noreply, assign(socket, :capture_handle, nil)}
  end

  def handle_event("transcribe", %{"recording" => recording}, socket) do
    EarWitness.Transcription.Server.transcribe(recording)

    {:noreply, socket}
  end

  @impl true
  def handle_info(%LocalSettings{input: input, output: output}, socket) do
    {:noreply,
     assign(socket,
       selected_input: input,
       selected_output: output
     )}
  end

  def handle_info(:deleted, socket),
    do: {:noreply, assign(socket, :recordings, get_recordings())}

  def handle_info(:transcribed, %{assigns: %{recordings: [recording | _]}} = socket) do
    EarWitness.Transcription.Server.transcribe(recording)
    {:noreply, assign(socket, :recordings, get_recordings())}
  end

  def handle_info(:transcribed, %{assigns: %{recordings: []}} = socket) do
    {:noreply, assign(socket, :recordings, get_recordings())}
  end

  def notification_event(action) do
    Desktop.Window.show_notification(TodoWindow, "You did '#{inspect(action)}' me!",
      id: :click,
      type: :warning
    )
  end

  def get_recordings(), do: EarWitness.recordings_dir() |> File.ls!()

  defp device_index(id) when is_integer(id) and id >= 0, do: id

  defp device_index(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} -> device_index(int)
      _ -> -1
    end
  end

  defp device_index(_id), do: -1
end
