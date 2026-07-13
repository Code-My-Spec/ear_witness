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
          <h2 class="card-title">Tags</h2>
          <div class="flex flex-wrap items-center gap-2">
            <span
              :for={tag <- @recording.collections}
              data-test="recording-tag"
              data-tag-id={tag.id}
              class="badge badge-secondary gap-1"
            >
              {tag.name}
              <button
                type="button"
                data-test="remove-tag"
                data-tag-id={tag.id}
                phx-click="remove_tag"
                phx-value-tag_id={tag.id}
                aria-label={"Remove tag #{tag.name}"}
                class="opacity-70 hover:opacity-100"
              >
                ✕
              </button>
            </span>

            <form id="add-tag-form" data-test="add-tag-form" phx-submit="add_tag" class="inline-flex">
              <input
                type="text"
                name="tag_name"
                data-test="add-tag-input"
                list="tag-suggestions"
                placeholder="Add a tag…"
                autocomplete="off"
                class="input input-bordered input-xs"
              />
              <datalist id="tag-suggestions">
                <option :for={tag <- @all_tags} value={tag.name} />
              </datalist>
            </form>
          </div>
          <p :if={@recording.collections == []} class="text-sm opacity-70">
            No tags yet — type one above to add it.
          </p>
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
          <%!--
            Render segments whenever any exist — during a live recording they
            stream in with status :transcribing and no speaker (story 872), and
            once the recording stops + diarizes they carry speaker labels. The
            "no speech" message is only meaningful once transcription is done.
          --%>
          <div
            :if={@transcript && (@transcript.status == :completed or @transcript.segments != [])}
            data-test="transcript"
            class="space-y-2"
          >
            <p
              :if={@transcript.status == :completed and @transcript.segments == []}
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
              <span
                :if={@transcript.status == :completed and @transcript.diarized_at}
                data-test="segment-speaker"
                data-segment-id={segment.id}
                class="badge badge-ghost badge-sm"
              >
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
     |> assign(recording: recording, all_tags: Recordings.list_collections())
     |> assign_transcript()}
  end

  @impl true
  def handle_event("transcribe", _params, socket) do
    {:ok, _transcript} = Transcription.transcribe(socket.assigns.recording)
    {:noreply, assign_transcript(socket)}
  end

  def handle_event("add_tag", %{"tag_name" => name}, socket) do
    {:ok, recording} = Recordings.add_recording_tag(socket.assigns.recording, name)

    {:noreply,
     socket
     |> assign(recording: recording, all_tags: Recordings.list_collections())}
  end

  def handle_event("remove_tag", %{"tag_id" => tag_id}, socket) do
    {:ok, recording} = Recordings.remove_recording_tag(socket.assigns.recording, tag_id)
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
