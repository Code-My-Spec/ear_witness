defmodule EarWitness.Transcription.Server do
  @moduledoc """
  Legacy transcription queue behind `EarWitnessWeb.TodoLive` (the
  `/legacy-todo` screen) — serializes one whisper.cpp NIF transcription at
  a time over recordings dropped in `EarWitness.recordings_dir()`, writing
  the result as a text file under the transcripts directory and deleting
  the source recording once done.
  """

  use GenServer
  require Logger

  defstruct [:task, working?: false]
  @topic "transcription"

  def subscribe() do
    Phoenix.PubSub.subscribe(EarWitness.PubSub, @topic)
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, %__MODULE__{}, name: __MODULE__)
  end

  def transcribe(file_name) do
    GenServer.cast(__MODULE__, {:transcribe, file_name})
  end

  def init(state) do
    {:ok, state}
  end

  def handle_cast({:transcribe, _file_name}, %{working?: true} = state) do
    {:noreply, state}
  end

  def handle_cast({:transcribe, file_name}, state) do
    file_path = Path.join([EarWitness.recordings_dir(), file_name])

    case File.stat!(file_path) do
      %{size: size} when size < 10_000 ->
        File.rm!(file_path)
        Phoenix.PubSub.broadcast(EarWitness.PubSub, @topic, :deleted)
        {:noreply, state}

      _ ->
        task =
          Task.async(fn ->
            {file_path, EarWitness.Transcribe.transcribe_files([file_path])}
          end)

        {:noreply, %{state | task: task, working?: true}}
    end
  end

  def handle_info({ref, {file_path, results}}, %{task: %Task{ref: ref}} = state) do
    Process.demonitor(ref, [:flush])
    Logger.info("Done Transcribing File")

    text =
      results
      |> to_string()
      |> Jason.decode!()
      |> Enum.flat_map(&Map.get(&1, "transcription", []))
      |> Enum.map_join("\n\n", &String.trim(Map.get(&1, "text", "")))

    text_file_path =
      file_path
      |> Path.rootname()
      |> Kernel.<>(".txt")
      |> String.replace("recordings", "transcripts")

    File.write!(text_file_path, text)
    File.rm!(file_path)
    Phoenix.PubSub.broadcast(EarWitness.PubSub, @topic, :transcribed)

    {:noreply, %{state | task: nil, working?: false}}
  end

  def handle_info({:DOWN, _ref, :process, _pid, reason}, state) do
    if reason != :normal do
      Logger.error("Transcription task failed: #{inspect(reason)}")
    end

    {:noreply, %{state | task: nil, working?: false}}
  end
end
