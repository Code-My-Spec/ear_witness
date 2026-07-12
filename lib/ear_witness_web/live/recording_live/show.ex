defmodule EarWitnessWeb.RecordingLive.Show do
  @moduledoc """
  One recording — playback metadata, transcribe action, live job
  progress, the timestamped transcript, and case ("collection")
  membership.
  """

  use EarWitnessWeb, :live_view

  alias EarWitness.Recordings
  alias EarWitness.Speakers
  alias EarWitness.Transcription
  alias EarWitnessWeb.RecordingLive.Format

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 space-y-6">
      <h1 data-test="recording-title" class="text-2xl font-bold">{@recording.title}</h1>
      <div class="flex gap-4 text-sm opacity-70">
        <span data-test="recording-duration">{Format.duration(@recording.duration)}</span>
        <span data-test="recording-source">{@recording.source}</span>
        <span data-test="recording-date">{@recording.date}</span>
        <span data-test="recording-participants">{@recording.participants}</span>
      </div>

      <div :for={collection <- @recording.collections} data-test="recording-collection" class="badge">
        {collection.name}
      </div>

      <button type="button" data-test="delete-recording-button" phx-click="trash_recording" class="btn btn-error btn-sm">
        Delete
      </button>

      <div class="card bg-base-100 shadow-sm">
        <div class="card-body">
          <h2 class="card-title">Metadata</h2>
          <form id="recording-metadata-form" data-test="recording-metadata-form" phx-submit="save_metadata">
            <input type="text" name="recording[title]" value={@recording.title} class="input input-bordered" />
            <input type="date" name="recording[date]" value={@recording.date} class="input input-bordered" />
            <input
              type="text"
              name="recording[participants]"
              value={@recording.participants}
              class="input input-bordered"
            />
            <button type="submit" class="btn btn-primary">Save</button>
          </form>
        </div>
      </div>

      <div class="card bg-base-100 shadow-sm">
        <div class="card-body">
          <h2 class="card-title">Cases</h2>
          <form id="recording-collections-form" data-test="recording-collections-form" phx-change="set_collections">
            <label :for={collection <- @collections} data-test="collection-option" data-collection-id={collection.id} class="flex items-center gap-2">
              {collection.name}
              <input
                type="checkbox"
                name="recording[collection_ids][]"
                value={collection.id}
                checked={collection.id in Enum.map(@recording.collections, & &1.id)}
              />
            </label>
          </form>
        </div>
      </div>

      <div :if={@recording.summary} class="card bg-base-100 shadow-sm">
        <div class="card-body">
          <h2 class="card-title">Summary</h2>
          <p data-test="recording-summary">{@recording.summary}</p>
        </div>
      </div>

      <div class="card bg-base-100 shadow-sm">
        <div class="card-body">
          <h2 class="card-title">Transcript</h2>
          <button
            :if={is_nil(@transcript)}
            type="button"
            data-test="transcribe-button"
            phx-click="transcribe"
            class="btn btn-primary"
          >
            Transcribe
          </button>
          <div :if={@transcript && @transcript.status != :completed} data-test="job-status">
            {@transcript.status}
          </div>
          <div :if={@transcript && @transcript.status == :completed} data-test="transcript" class="space-y-2">
            <p
              :if={@transcript.segments == []}
              data-test="transcript-empty"
              class="text-sm opacity-70 italic"
            >
              No speech was detected in this recording.
            </p>
            <div :for={segment <- @transcript.segments} data-test="transcript-segment" data-segment-id={segment.id} class="flex gap-2">
              <span data-test="segment-timestamp" class="opacity-60">
                {Format.duration(segment.start_offset / 1000)}
              </span>
              <span data-test="segment-speaker" data-segment-id={segment.id}>
                {@speaker_labels[segment.id]}
              </span>
              <span>{segment.text}</span>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok, recording} = Recordings.get_recording(id)

    if connected?(socket), do: Transcription.subscribe(recording.id)

    {:ok,
     socket
     |> assign(recording: recording, collections: Recordings.list_collections())
     |> assign_transcript()}
  end

  @impl true
  def handle_event("transcribe", _params, socket) do
    {:ok, _transcript} = Transcription.transcribe(socket.assigns.recording)
    {:noreply, assign_transcript(socket)}
  end

  def handle_event("save_metadata", %{"recording" => params}, socket) do
    {:ok, recording} = Recordings.update_recording(socket.assigns.recording, params)
    {:noreply, assign(socket, :recording, recording)}
  end

  def handle_event("set_collections", %{"recording" => params}, socket) do
    ids =
      params
      |> Map.get("collection_ids", [])
      |> List.wrap()
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(&String.to_integer/1)

    {:ok, recording} = Recordings.set_recording_collections(socket.assigns.recording, ids)
    {:noreply, assign(socket, :recording, recording)}
  end

  def handle_event("trash_recording", _params, socket) do
    {:ok, _recording} = Recordings.trash_recording(socket.assigns.recording)
    {:noreply, push_navigate(socket, to: ~p"/recordings")}
  end

  @impl true
  def handle_info({:transcription_status, _status}, socket) do
    {:noreply, assign_transcript(socket)}
  end

  # Diarizes (idempotently) the moment a completed transcript is loaded, so
  # every segment carries speaker attribution without a separate action —
  # same as `TranscriptLive.Editor.load_transcript/1`.
  defp assign_transcript(socket) do
    case fetch_transcript(socket.assigns.recording.id) do
      %{status: :completed} = transcript ->
        :ok = Speakers.diarize_transcript(transcript)
        transcript = fetch_transcript(socket.assigns.recording.id)
        speakers = Speakers.list_speakers_for_transcript(transcript)

        assign(socket,
          transcript: transcript,
          speaker_labels: speaker_labels(transcript.segments, speakers)
        )

      transcript ->
        assign(socket, transcript: transcript, speaker_labels: %{})
    end
  end

  defp fetch_transcript(recording_id) do
    case Transcription.get_transcript_for_recording(recording_id) do
      {:ok, transcript} -> transcript
      {:error, :not_found} -> nil
    end
  end

  defp speaker_labels(segments, speakers) do
    speakers_by_id =
      speakers
      |> Enum.with_index()
      |> Map.new(fn {speaker, index} -> {speaker.id, {speaker, index}} end)

    Map.new(segments, fn segment ->
      {speaker, index} = Map.get(speakers_by_id, segment.speaker_id, {nil, 0})
      {segment.id, Speakers.label(speaker, index)}
    end)
  end
end
