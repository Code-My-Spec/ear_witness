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
            "card card-body cursor-pointer gap-2 border bg-base-100 text-base leading-relaxed shadow-sm transition-colors",
            (segment.id == @focused_segment_id && "border-primary ring ring-primary/30") ||
              "border-base-300",
            segment.id == @playing_segment_id && "bg-primary/5"
          ]}
        >
          {segment.text}
          <span :if={segment.id == @focused_segment_id} data-test="focused-segment" class="hidden">
            {segment.text}
          </span>
          <span
            :if={segment.id == @playing_segment_id}
            data-test="playing-segment"
            class="badge badge-accent badge-sm w-fit gap-1"
          >
            <.icon name="hero-play-circle" class="size-3.5" /> Playing
          </span>

          <div class="flex flex-wrap items-center gap-2 text-sm opacity-70">
            <span data-test="segment-timestamp" class="tnum">
              {Format.duration(segment.start_offset / 1000)}
            </span>
            <span
              data-test="segment-speaker"
              data-segment-id={segment.id}
              class="badge badge-ghost badge-sm"
            >
              {@speaker_labels[segment.id]}
            </span>
          </div>

          <form
            id={"segment-editor-#{segment.id}"}
            data-test="segment-editor"
            data-segment-id={segment.id}
            phx-submit="edit_segment_text"
            phx-value-id={segment.id}
            onclick="event.stopPropagation()"
            class="flex items-center gap-2"
          >
            <input
              type="text"
              name="segment[text]"
              value={segment.text}
              class="input input-bordered input-sm flex-1"
            />
            <button type="submit" class="btn btn-sm">Save</button>
          </form>

          <form
            id={"segment-speaker-form-#{segment.id}"}
            data-test="segment-speaker-form"
            data-segment-id={segment.id}
            phx-change="reassign_segment_speaker"
            phx-value-id={segment.id}
            onclick="event.stopPropagation()"
          >
            <select name="segment[speaker_id]" class="select select-bordered select-sm">
              <option
                :for={{speaker, index} <- Enum.with_index(@speakers)}
                value={speaker.id}
                selected={speaker.id == segment.speaker_id}
              >
                {Speakers.label(speaker, index)}
              </option>
            </select>
          </form>

          <button
            type="button"
            data-test="revert-button"
            data-segment-id={segment.id}
            phx-click="revert_segment"
            phx-value-id={segment.id}
            class="btn btn-sm btn-ghost self-start"
          >
            <.icon name="hero-arrow-uturn-left" class="size-3.5" /> Revert to original
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

  def handle_event("edit_segment_text", %{"id" => id, "segment" => %{"text" => text}}, socket) do
    {:ok, _segment} = Transcription.update_segment_text(String.to_integer(id), text)
    {:noreply, load_transcript(socket)}
  end

  def handle_event(
        "reassign_segment_speaker",
        %{"id" => id, "segment" => %{"speaker_id" => speaker_id}},
        socket
      ) do
    {:ok, _segment} =
      Transcription.reassign_segment_speaker(String.to_integer(id), String.to_integer(speaker_id))

    {:noreply, load_transcript(socket)}
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
      speaker_labels: speaker_labels(transcript.segments, speakers)
    )
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
