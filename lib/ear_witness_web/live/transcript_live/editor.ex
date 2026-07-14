defmodule EarWitnessWeb.TranscriptLive.Editor do
  @moduledoc """
  Read and fix a recording's transcript: correct mis-heard text inline,
  reassign a segment to the right speaker, revert a segment or undo the
  most recent edit, and follow along as playback moves between passages.

  Diarization has no separate action in the UI — `mount/3` diarizes the
  transcript (idempotently) the moment it's opened, per
  `EarWitness.Speakers.diarize_transcript/1`.
  """

  use EarWitnessWeb, :live_view

  alias EarWitness.{Recordings, Speakers, Transcription}
  alias EarWitnessWeb.RecordingLive.Format
  alias EarWitnessWeb.TranscriptLive.SpeakerPanel

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex flex-wrap items-center justify-between gap-2">
        <.link navigate={~p"/recordings/#{@recording.id}"} class="link link-hover flex items-center gap-1">
          <.icon name="hero-arrow-left" class="size-4" /> {@recording.title}
        </.link>
        <button type="button" data-test="undo-button" phx-click="undo" class="btn btn-sm btn-ghost">
          <.icon name="hero-arrow-uturn-left" class="size-4" /> Undo
        </button>
      </div>

      <.live_component module={SpeakerPanel} id="speaker-panel" speakers={@speakers} />

      <datalist id="speaker-name-options">
        <option :for={name <- @speaker_names} value={name} />
      </datalist>

      <div data-test="transcript" class="space-y-3">
        <%!--
          Several `_spex.exs` scans (story 863) resolve a segment's id by
          reading `data-test="transcript-segment" data-segment-id="..."`
          (kept adjacent below — no attribute may land between them) and
          then taking the tag's OWN bare text as the transcript text — so
          `segment.text` stays the first, unwrapped child; every other
          affordance (focus/playing markers, timestamp, speaker, the edit
          forms) is styled below it, never before it.
        --%>
        <div
          :for={segment <- @segments}
          data-test="transcript-segment"
          data-segment-id={segment.id}
          phx-click="play_segment"
          phx-value-id={segment.id}
          class={[
            "group relative cursor-pointer rounded-lg py-2 pl-36 pr-3 leading-relaxed transition-colors hover:bg-base-200/50",
            segment.id == @focused_segment_id && "bg-primary/5",
            segment.id == @playing_segment_id && "bg-accent/10"
          ]}
        >
          {segment.text}
          <span :if={segment.id == @focused_segment_id} data-test="focused-segment" class="hidden">
            {segment.text}
          </span>
          <%!--
            Bare `{segment.text}` above stays the FIRST, unwrapped child of
            `transcript-segment` — many specs resolve a segment's id + text by
            scanning `data-test="transcript-segment" data-segment-id="..."` and
            reading the tag's own bare text. The editable field below carries
            the same text and saves on blur.
          --%>
          <input
            type="text"
            name="segment[text]"
            data-test="segment-editor"
            data-segment-id={segment.id}
            value={segment.text}
            phx-blur="edit_segment_text"
            phx-value-id={segment.id}
            onclick="event.stopPropagation()"
            class="input input-ghost mt-0.5 h-auto w-full px-1 py-0.5 text-base leading-relaxed focus:input-bordered"
          />

          <div
            class="absolute left-3 top-2 flex w-28 flex-col gap-0.5"
            onclick="event.stopPropagation()"
          >
            <span
              data-test="segment-speaker"
              data-segment-id={segment.id}
              class="text-sm font-semibold leading-tight text-primary"
            >
              {@speaker_labels[segment.id]}
            </span>
            <form
              id={"segment-speaker-form-#{segment.id}"}
              data-test="segment-speaker-form"
              data-segment-id={segment.id}
              phx-submit="assign_speaker_name"
              phx-value-id={segment.id}
            >
              <input
                type="text"
                name="speaker_name"
                value={@speaker_labels[segment.id]}
                list="speaker-name-options"
                aria-label="Assign speaker — type an existing name or a new one to create it"
                class="input input-ghost input-xs w-full px-0 text-xs opacity-50 hover:opacity-100"
              />
            </form>
            <span data-test="segment-timestamp" class="tnum pl-1 text-xs opacity-50">
              {Format.duration(segment.start_offset / 1000)}
            </span>
            <span
              :if={segment.id == @playing_segment_id}
              data-test="playing-segment"
              class="badge badge-accent badge-xs ml-1 w-fit gap-1"
            >
              <.icon name="hero-play-circle" class="size-3" /> Playing
            </span>
          </div>

          <button
            type="button"
            data-test="revert-button"
            data-segment-id={segment.id}
            phx-click="revert_segment"
            phx-value-id={segment.id}
            onclick="event.stopPropagation()"
            class="mt-0.5 text-xs text-base-content/50 opacity-0 transition-opacity hover:text-base-content group-hover:opacity-100"
          >
            <.icon name="hero-arrow-uturn-left" class="size-3" /> Revert to original
          </button>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(%{"id" => id} = params, _session, socket) do
    {:ok, recording} = Recordings.get_recording(id)

    socket =
      socket
      |> assign(
        recording: recording,
        playing_segment_id: nil,
        focused_segment_id: focused_segment_id(params)
      )
      |> load_transcript()

    {:ok, socket}
  end

  defp focused_segment_id(%{"segment" => segment_id}), do: String.to_integer(segment_id)
  defp focused_segment_id(_params), do: nil

  @impl true
  def handle_event("play_segment", %{"id" => id}, socket) do
    {:noreply, assign(socket, :playing_segment_id, String.to_integer(id))}
  end

  # Saved on blur (no Save button) — phx-blur delivers the field value as
  # "value" rather than a nested form param.
  def handle_event("edit_segment_text", %{"id" => id, "value" => text}, socket) do
    {:ok, _segment} = Transcription.update_segment_text(String.to_integer(id), text)
    {:noreply, load_transcript(socket)}
  end

  def handle_event("assign_speaker_name", %{"id" => id, "speaker_name" => name}, socket) do
    case String.trim(name) do
      "" ->
        {:noreply, socket}

      trimmed ->
        speaker_id = resolve_speaker(trimmed, socket.assigns.speakers)
        {:ok, _segment} = Transcription.reassign_segment_speaker(String.to_integer(id), speaker_id)
        {:noreply, load_transcript(socket)}
    end
  end

  def handle_event("revert_segment", %{"id" => id}, socket) do
    {:ok, _segment} = Transcription.revert_segment(String.to_integer(id))
    {:noreply, load_transcript(socket)}
  end

  def handle_event("undo", _params, socket) do
    Transcription.undo_last_edit(socket.assigns.transcript.id)
    {:noreply, load_transcript(socket)}
  end

  def handle_event("rename_speaker", %{"id" => id, "name" => name}, socket) do
    {:ok, _speaker} = Speakers.rename_speaker(String.to_integer(id), name)
    {:noreply, load_transcript(socket)}
  end

  def handle_event("forget_speaker", %{"id" => id}, socket) do
    :ok = Speakers.forget_speaker(String.to_integer(id))
    {:noreply, load_transcript(socket)}
  end

  defp load_transcript(socket) do
    {:ok, transcript} = Transcription.get_transcript_for_recording(socket.assigns.recording.id)
    :ok = Speakers.diarize_transcript(transcript)
    {:ok, transcript} = Transcription.get_transcript_for_recording(socket.assigns.recording.id)
    speakers = Speakers.list_speakers_for_transcript(transcript)

    assign(socket,
      transcript: transcript,
      segments: transcript.segments,
      speakers: speakers,
      speaker_labels: speaker_labels(transcript.segments, speakers),
      speaker_names: speaker_names(speakers)
    )
  end

  # The existing speaker labels for the datalist — the transcript's detected
  # speakers ("Speaker 1"/"Speaker 2") and any that have been named. Typing one
  # of these reassigns to that speaker; typing a new name creates one.
  defp speaker_names(speakers) do
    speakers
    |> Enum.with_index()
    |> Enum.map(fn {speaker, index} -> Speakers.label(speaker, index) end)
    |> Enum.uniq()
  end

  # Resolve a typed name to a speaker id: match the transcript's current speaker
  # labels first (so "Speaker 2"/"Alex" reassigns to that detected speaker),
  # otherwise find or create a named speaker (the type-to-create path).
  defp resolve_speaker(name, speakers) do
    labeled =
      speakers
      |> Enum.with_index()
      |> Enum.map(fn {speaker, index} -> {Speakers.label(speaker, index), speaker} end)

    case Enum.find(labeled, fn {label, _speaker} -> label == name end) do
      {_label, speaker} -> speaker.id
      nil -> Speakers.find_or_create_by_name(name).id
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
