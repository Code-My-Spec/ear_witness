defmodule EarWitnessWeb.RecordingLive.Index do
  @moduledoc """
  Recordings library — browse recordings grouped by case/collection,
  import or record new ones, organize them into cases, and (on the
  `:trash` action) restore recordings sent to the trash.
  """

  use EarWitnessWeb, :live_view

  alias EarWitness.Recordings
  alias EarWitness.Recordings.Collection
  alias EarWitness.Transcription
  alias EarWitnessWeb.RecordingLive.Format

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <div class="flex items-center justify-between">
        <h1 class="text-2xl font-bold">Recordings</h1>
        <.link :if={@live_action == :trash} navigate={~p"/recordings"} class="btn btn-ghost btn-sm">
          <.icon name="hero-arrow-left" class="size-4" /> Back to library
        </.link>
      </div>

      <div :if={@live_action == :index} class="space-y-8">
        <div class="card bg-base-100 border border-base-300 shadow-sm">
          <div class="card-body">
            <h2 class="card-title">
              <.icon name="hero-microphone" class="size-5 text-primary" /> Record
            </h2>
            <div :if={@capture_error} data-test="capture-error" class="alert alert-error">
              <.icon name="hero-exclamation-circle" class="size-5" />
              {@capture_error}
            </div>
            <div class="flex flex-wrap items-center gap-2">
              <div :if={@capturing?} data-test="capture-status" class="badge badge-error gap-1">
                <span class="inline-block size-2 animate-pulse rounded-full bg-current"></span>
                recording
              </div>
              <div :if={@capture_channels} data-test="capture-channels" class="text-sm opacity-70">
                {Format.channels(@capture_channels)}
              </div>
            </div>
            <div :if={@capture_notice == :shown} data-test="capture-notice" class="alert alert-info">
              <.icon name="hero-information-circle" class="size-5" />
              A notice is shown to participants that recording is active.
            </div>
            <div
              :if={@capture_notice == :delivered}
              data-test="announce-notice-status"
              class="text-sm opacity-70"
            >
              delivered
            </div>
            <div class="flex gap-2">
              <button type="button" class="btn btn-primary" phx-click="record" disabled={@capturing?}>
                <.icon name="hero-play" class="size-4" /> Record
              </button>
              <button type="button" class="btn" phx-click="stop" disabled={!@capturing?}>
                <.icon name="hero-stop" class="size-4" /> Stop
              </button>
            </div>
          </div>
        </div>

        <div
          :if={@live_recording_id}
          data-test="live-transcript"
          class="card bg-base-100 border border-base-300 shadow-sm"
        >
          <div class="card-body">
            <h2 class="card-title">
              <span :if={@capturing?} class="loading loading-spinner loading-xs"></span>
              Live transcript
            </h2>
            <p
              :if={@live_segments == []}
              data-test="live-transcript-empty"
              class="text-sm opacity-70"
            >
              Listening… transcript segments appear here as they're recognized.
            </p>
            <div class="space-y-1">
              <div
                :for={segment <- @live_segments}
                data-test="live-segment"
                data-segment-id={segment.id}
                class="flex flex-wrap items-baseline gap-2"
              >
                <span class="tnum text-xs opacity-60">
                  {Format.duration(segment.start_offset / 1000)}
                </span>
                <span>{segment.text}</span>
              </div>
            </div>
          </div>
        </div>

        <div class="card bg-base-100 border border-base-300 shadow-sm">
          <div class="card-body">
            <h2 class="card-title">
              <.icon name="hero-arrow-up-tray" class="size-5 text-primary" /> Import a recording
            </h2>
            <div :if={@import_error} data-test="import-error" class="alert alert-error">
              <.icon name="hero-exclamation-circle" class="size-5" />
              {@import_error}
            </div>
            <form
              id="import-form"
              data-test="import-form"
              phx-submit="import"
              phx-change="validate_import"
              class="flex flex-wrap items-center gap-2"
            >
              <.live_file_input
                upload={@uploads.audio_file}
                class="file-input file-input-bordered file-input-sm"
              />
              <button type="submit" class="btn btn-primary btn-sm">Import</button>
            </form>
          </div>
        </div>

        <div class="card bg-base-100 border border-base-300 shadow-sm">
          <div class="card-body">
            <h2 class="card-title">
              <.icon name="hero-tag" class="size-5 text-primary" /> Tags
            </h2>
            <form
              id="collection-form"
              data-test="collection-form"
              phx-submit="create_collection"
              class="flex flex-wrap items-end gap-2"
            >
              <input
                type="text"
                name="collection[name]"
                placeholder="Tag name"
                class="input input-bordered input-sm"
              />
              <button type="submit" class="btn btn-sm">Create tag</button>
            </form>

            <div :if={@collection_error} data-test="collection-error" class="alert alert-error mt-2">
              <.icon name="hero-exclamation-triangle" class="size-5" />
              {@collection_error}
            </div>
            <%!--
              `EarWitnessSpex.CollectionSteps.collection_id/2` resolves a
              case's id by scanning for `data-collection-id="..."` and
              reading the element's own bare text as the case name — so
              `collection.name` must render as the FIRST, unwrapped child
              of this container. Style everything else (the delete button,
              the recording list) below that bare text, never before it.
            --%>
            <div
              :for={collection <- @collections}
              data-test="collection"
              data-collection-id={collection.id}
              class="mt-4 space-y-2 border-t border-base-200 pt-4 font-medium first:mt-0 first:border-t-0 first:pt-0"
            >
              {collection.name}
              <div class="flex items-center justify-between font-normal">
                <span class="text-xs opacity-60">
                  {length(collection.recordings)} recording(s)
                </span>
                <button
                  type="button"
                  data-test="delete-collection-button"
                  data-collection-id={collection.id}
                  phx-click="delete_collection"
                  phx-value-id={collection.id}
                  class="btn btn-xs btn-ghost"
                >
                  <.icon name="hero-x-mark" class="size-3.5" /> Delete tag
                </button>
              </div>
              <div class="space-y-1 pl-2">
                <.recording_row :for={recording <- collection.recordings} recording={recording} />
              </div>
            </div>
          </div>
        </div>

        <div
          data-test="uncategorized-recordings"
          class="card bg-base-100 border border-base-300 shadow-sm"
        >
          <div class="card-body">
            <h2 class="card-title">Untagged</h2>
            <p :if={@uncategorized == []} class="text-sm opacity-70">Nothing here yet.</p>
            <div class="space-y-1">
              <.recording_row :for={recording <- @uncategorized} recording={recording} />
            </div>
          </div>
        </div>

        <div class="flex justify-end">
          <.link navigate={~p"/recordings/trash"} class="link link-hover text-sm opacity-70">
            <.icon name="hero-trash" class="size-3.5" /> View trash
          </.link>
        </div>
      </div>

      <div :if={@live_action == :trash} class="space-y-4">
        <div data-test="trash-retention-notice" class="alert alert-warning">
          <.icon name="hero-exclamation-triangle" class="size-5" />
          Trashed recordings are kept for 30 days before permanent removal.
        </div>
        <p :if={@trashed_recordings == []} class="text-sm opacity-70">The trash is empty.</p>
        <div
          :for={recording <- @trashed_recordings}
          data-test="trash-row"
          data-recording-id={recording.id}
          class="card bg-base-100 border border-base-300 shadow-sm"
        >
          <div class="card-body flex-row items-center justify-between py-3">
            <span>{recording.title}</span>
            <button
              type="button"
              data-test="restore-button"
              phx-click="restore"
              phx-value-id={recording.id}
              class="btn btn-xs"
            >
              <.icon name="hero-arrow-uturn-left" class="size-3.5" /> Restore
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :recording, EarWitness.Recordings.Recording, required: true

  defp recording_row(assigns) do
    ~H"""
    <div
      data-test="recording-row"
      data-recording-id={@recording.id}
      class="flex flex-wrap items-center gap-3 rounded-lg px-2 py-1.5 hover:bg-base-200"
    >
      <.icon name="hero-document-text" class="size-4 shrink-0 opacity-60" />
      <a href={~p"/recordings/#{@recording.id}"} class="link link-hover flex-1 min-w-0 truncate">
        {@recording.title}
      </a>
      <span data-test="recording-duration" class="tnum badge badge-ghost badge-sm">
        {Format.duration(@recording.duration)}
      </span>
      <span data-test="recording-source" class="badge badge-outline badge-sm">
        {source_label(@recording)}
      </span>
    </div>
    """
  end

  # Every live capture now records the microphone + system audio together (story
  # 872 UAT), so there's no mic-vs-tap distinction to surface — a captured
  # recording is just "captured". Imported and bot-sourced recordings display
  # their `source` as-is.
  defp source_label(%{source: source}), do: to_string(source)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       import_error: nil,
       collection_error: nil,
       capture_error: nil,
       capturing?: false,
       capture_ref: nil,
       capture_channels: nil,
       capture_notice: nil,
       live_recording_id: nil,
       live_segments: []
     )
     |> resume_running_capture()
     |> reload_library()
     |> allow_upload(:audio_file, accept: ~w(.wav), max_entries: 1)}
  end

  # Picks a still-running capture back up on mount. Capture state used to
  # live only in this view's assigns, so any remount (dev live-reload,
  # navigating away and back, a webview reload, an LV crash) reset the UI to
  # an idle Record button while the capture kept running — impossible to
  # stop, transcript stuck :transcribing forever.
  defp resume_running_capture(socket) do
    case Recordings.running_live_capture() do
      nil ->
        socket

      %{ref: ref, channels: channels, recording_id: recording_id} ->
        if connected?(socket), do: Transcription.subscribe(recording_id)

        segments =
          case Transcription.get_transcript_for_recording(recording_id) do
            {:ok, transcript} -> transcript.segments
            _ -> []
          end

        assign(socket,
          capturing?: true,
          capture_ref: ref,
          capture_channels: channels,
          live_recording_id: recording_id,
          live_segments: segments
        )
    end
  end

  @impl true
  def handle_event("validate_import", _params, socket), do: {:noreply, socket}

  def handle_event("import", _params, socket) do
    # The temp upload file is removed as soon as this callback returns, so
    # the import (which reads it) must happen inside the callback rather
    # than being deferred to after `consume_uploaded_entries/3` returns.
    case consume_uploaded_entries(socket, :audio_file, fn %{path: path}, entry ->
           {:ok, Recordings.import_recording(path, entry.client_name)}
         end) do
      [result] -> {:noreply, handle_import_result(socket, result)}
      [] -> {:noreply, assign(socket, :import_error, "Choose a file to import.")}
    end
  end

  def handle_event("record", _params, socket) do
    {:noreply, handle_record(socket)}
  end

  def handle_event("stop", _params, socket) do
    {:noreply, handle_stop(socket)}
  end

  def handle_event("create_collection", %{"collection" => params}, socket) do
    case Recordings.create_collection(params) do
      {:ok, _collection} ->
        {:noreply, socket |> assign(:collection_error, nil) |> reload_library()}

      {:error, changeset} ->
        {:noreply, assign(socket, :collection_error, collection_error_message(changeset))}
    end
  end

  def handle_event("delete_collection", %{"id" => id}, socket) do
    {:ok, _collection} = Recordings.delete_collection(%Collection{id: String.to_integer(id)})
    {:noreply, reload_library(socket)}
  end

  def handle_event("restore", %{"id" => id}, socket) do
    {:ok, recording} = Recordings.get_recording(id)
    {:ok, _recording} = Recordings.restore_recording(recording)
    {:noreply, reload_library(socket)}
  end

  # Turns a rejected collection changeset into a human message for the
  # create-case form, so a blank/invalid name surfaces an error instead of
  # silently no-opping (issue b656b47c). Falls back to a generic message.
  defp collection_error_message(changeset) do
    case changeset.errors[:name] do
      {msg, _opts} -> "Case name #{msg}."
      _ -> "That case couldn't be created."
    end
  end

  defp handle_import_result(socket, result) do
    case result do
      {:ok, _recording} ->
        socket |> assign(:import_error, nil) |> reload_library()

      {:error, :invalid_audio_file} ->
        assign(
          socket,
          :import_error,
          "That file couldn't be imported — it isn't a usable recording."
        )

      {:error, _changeset} ->
        assign(socket, :import_error, "That file couldn't be imported.")
    end
  end

  @impl true
  def handle_info({:transcription_status, _status}, socket) do
    # Live transcript advanced (a new batch of segments, completion, or
    # diarization) — re-fetch and re-render the streaming segment list.
    segments =
      with id when not is_nil(id) <- socket.assigns.live_recording_id,
           {:ok, transcript} <- Transcription.get_transcript_for_recording(id) do
        transcript.segments
      else
        _ -> socket.assigns.live_segments
      end

    {:noreply, assign(socket, :live_segments, segments)}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  defp handle_record(socket) do
    case Recordings.start_live_capture() do
      {:ok, %{ref: ref, channels: channels, notice: notice, recording_id: recording_id}} ->
        # A real device-backed capture streams a live transcript (story 872);
        # subscribe so segments render as they're transcribed. recording_id is
        # nil for a fixture capture, which has no live transcription.
        if recording_id, do: Transcription.subscribe(recording_id)

        assign(socket,
          capture_ref: ref,
          capturing?: true,
          capture_channels: channels,
          capture_notice: notice,
          capture_error: nil,
          live_recording_id: recording_id,
          live_segments: []
        )

      {:error, :no_input_device} ->
        assign(socket,
          capture_error: "No input device is available.",
          capturing?: false,
          capture_notice: nil
        )

      {:error, :notice_undelivered} ->
        assign(socket,
          capture_error:
            "The announce policy's notice couldn't be delivered — capture was refused.",
          capturing?: false,
          capture_notice: nil
        )

      {:error, :source_unavailable} ->
        assign(socket,
          capture_error: "That capture source isn't available.",
          capturing?: false,
          capture_notice: nil
        )
    end
  end

  defp handle_stop(socket) do
    case Recordings.finish_live_capture(socket.assigns.capture_ref) do
      {:ok, _recording, channels} ->
        # Clear capture_notice — leaving it set keeps a stale "recording is
        # active" notice on screen after recording has stopped, which is
        # exactly the consent mechanic story 861 depends on (861 QA finding).
        socket
        |> assign(capturing?: false, capture_ref: nil, capture_channels: channels, capture_notice: nil)
        |> reload_library()

      {:error, reason} ->
        # Never swallow a failed capture silently — the user just lost a
        # recording and must be told (story-860 QA finding).
        assign(socket,
          capturing?: false,
          capture_ref: nil,
          capture_notice: nil,
          capture_error: "Recording could not be saved (#{format_capture_error(reason)})."
        )
    end
  end

  defp format_capture_error(:invalid_audio_file), do: "the captured audio file was not readable"
  defp format_capture_error(%Ecto.Changeset{}), do: "it could not be added to the library"
  defp format_capture_error(other), do: inspect(other)

  defp reload_library(socket) do
    assign(socket,
      collections: Recordings.list_collections(),
      uncategorized: Recordings.list_uncategorized_recordings(),
      trashed_recordings: Recordings.list_trashed_recordings()
    )
  end
end
