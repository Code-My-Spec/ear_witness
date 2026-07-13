defmodule EarWitnessWeb.RecordingLive.Show do
  @moduledoc """
  One recording — its details, transcribe action, live job progress, the
  timestamped transcript, and case ("collection") membership.
  """

  use EarWitnessWeb, :live_view

  alias EarWitness.Recordings
  alias EarWitness.Speakers
  alias EarWitness.Transcription
  alias EarWitnessWeb.RecordingLive.Format

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex flex-wrap items-start justify-between gap-4">
        <div class="space-y-2">
          <h1 data-test="recording-title" class="text-2xl font-bold">{@recording.title}</h1>
          <div class="flex flex-wrap items-center gap-3 text-sm opacity-70">
            <span data-test="recording-duration" class="tnum badge badge-ghost badge-sm">
              {Format.duration(@recording.duration)}
            </span>
            <span data-test="recording-source" class="badge badge-outline badge-sm">
              {@recording.source}
            </span>
            <span data-test="recording-date">{@recording.date}</span>
            <span data-test="recording-participants">{@recording.participants}</span>
          </div>
          <div class="flex flex-wrap gap-2">
            <span :for={collection <- @recording.collections} data-test="recording-collection" class="badge badge-secondary badge-sm">
              {collection.name}
            </span>
          </div>
        </div>

        <button
          type="button"
          data-test="delete-recording-button"
          phx-click="trash_recording"
          class="btn btn-error btn-outline btn-sm"
        >
          <.icon name="hero-trash" class="size-4" /> Delete
        </button>
      </div>

      <div class="card bg-base-100 border border-base-300 shadow-sm">
        <div class="card-body">
          <h2 class="card-title">Cases</h2>
          <form id="recording-collections-form" data-test="recording-collections-form" phx-change="set_collections">
            <%!--
              `EarWitnessSpex.CollectionSteps.collection_id/2` resolves a
              case's id by reading this label's own bare text as its name
              — keep `collection.name` as the label's first, unwrapped
              child, ahead of the checkbox.
            --%>
            <label
              :for={collection <- @collections}
              data-test="collection-option"
              data-collection-id={collection.id}
              class="flex items-center justify-between gap-2 py-1"
            >
              {collection.name}
              <input
                type="checkbox"
                name="recording[collection_ids][]"
                value={collection.id}
                checked={collection.id in Enum.map(@recording.collections, & &1.id)}
                class="checkbox checkbox-sm"
              />
            </label>
            <p :if={@collections == []} class="text-sm opacity-70">No cases yet.</p>
          </form>
        </div>
      </div>

      <div :if={@recording.summary} class="card bg-base-100 border border-base-300 shadow-sm">
        <div class="card-body">
          <h2 class="card-title">
            <.icon name="hero-sparkles" class="size-5 text-primary" /> Summary
          </h2>
          <p data-test="recording-summary">{@recording.summary}</p>
        </div>
      </div>

      <div class="card bg-base-100 border border-base-300 shadow-sm">
        <div class="card-body">
          <div class="flex flex-wrap items-center justify-between gap-2">
            <h2 class="card-title">Transcript</h2>
            <.link
              :if={@transcript && @transcript.status == :completed}
              navigate={~p"/recordings/#{@recording.id}/transcript"}
              data-test="open-editor-link"
              class="btn btn-sm btn-outline"
            >
              <.icon name="hero-pencil-square" class="size-4" /> Open editor
            </.link>
          </div>
          <button
            :if={is_nil(@transcript) || @transcript.status == :failed}
            type="button"
            data-test="transcribe-button"
            phx-click="transcribe"
            class="btn btn-primary self-start"
          >
            <.icon name="hero-document-text" class="size-4" />
            {if @transcript, do: "Retry transcription", else: "Transcribe"}
          </button>
          <div
            :if={@transcript && @transcript.status != :completed}
            data-test="job-status"
            class="flex items-center gap-2 text-sm opacity-70"
          >
            <span class="loading loading-spinner loading-xs"></span> {@transcript.status}
          </div>
          <div :if={@transcript && @transcript.status == :completed} data-test="transcript" class="space-y-2">
            <p
              :if={@transcript.segments == []}
              data-test="transcript-empty"
              class="text-sm opacity-70 italic"
            >
              No speech was detected in this recording.
            </p>
            <div
              :for={segment <- @transcript.segments}
              data-test="transcript-segment"
              data-segment-id={segment.id}
              class="flex flex-wrap items-baseline gap-2 rounded-lg px-2 py-1.5 odd:bg-base-200/50"
            >
              <span data-test="segment-timestamp" class="tnum text-xs opacity-60">
                {Format.duration(segment.start_offset / 1000)}
              </span>
              <span data-test="segment-speaker" data-segment-id={segment.id} class="badge badge-ghost badge-sm">
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

  def handle_event("set_collections", params, socket) do
    # Unchecking the last checked box submits a form with no
    # `recording[collection_ids][]` field at all, so `params` carries no
    # "recording" key. Default it to %{} rather than pattern-matching on
    # it, so clearing the final case removes membership instead of the
    # event silently failing and the box snapping back (issue 4df46bc8).
    ids =
      params
      |> Map.get("recording", %{})
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
