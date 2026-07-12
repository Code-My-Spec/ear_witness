defmodule EarWitness.Transcription.Worker do
  @moduledoc """
  Oban worker that runs one recording's transcription job: calls the
  configured engine, persists the transcript's segments, and broadcasts
  status changes over PubSub for `EarWitness.Transcription.subscribe/1`
  listeners.
  """

  use Oban.Worker, queue: :default, max_attempts: 3

  alias EarWitness.Recordings.Recording
  alias EarWitness.Repo
  alias EarWitness.Search
  alias EarWitness.Speakers
  alias EarWitness.Transcription
  alias EarWitness.Transcription.{Segment, Transcript}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"recording_id" => recording_id}}) do
    recording = Repo.get!(Recording, recording_id)
    transcript = Repo.get_by!(Transcript, recording_id: recording_id)

    transcript |> update_status(:transcribing) |> broadcast(recording_id)

    engine =
      Application.get_env(:ear_witness, :transcription_engine, EarWitness.Transcription.Engine)

    case safe_transcribe(engine, recording.file_path) do
      {:ok, documents} ->
        insert_segments(transcript, documents)
        transcript |> update_status(:completed) |> broadcast(recording_id)
        index_for_search(recording_id)
        :ok

      {:error, reason} ->
        transcript |> update_status(:failed) |> broadcast(recording_id)
        {:error, reason}
    end
  end

  # The whisper NIF stub exits with :nif_library_not_loaded when the NIF is
  # gone (e.g. dev code reloading unloaded it — NIFs cannot be reloaded).
  # A bare exit bypassed the {:error, _} branch entirely, so the transcript
  # sat at :transcribing forever with no user-facing failure (story-860 QA
  # finding, issue 3d0c6279). Convert crashes into the normal failed path.
  defp safe_transcribe(engine, file_path) do
    engine.transcribe(file_path)
  rescue
    error -> {:error, Exception.message(error)}
  catch
    :exit, reason -> {:error, "transcription engine crashed: #{inspect(reason)}"}
  end

  # Attributes every segment to a detected speaker (idempotent — see
  # `Speakers.diarize_transcript/1`) before indexing, so search results
  # carry a real speaker label the moment transcription finishes rather
  # than only after a human opens the transcript editor.
  defp index_for_search(recording_id) do
    {:ok, transcript} = Transcription.get_transcript_for_recording(recording_id)
    :ok = Speakers.diarize_transcript(transcript)
    {:ok, transcript} = Transcription.get_transcript_for_recording(recording_id)
    Search.index_transcript(transcript)
  end

  defp update_status(transcript, status) do
    {:ok, transcript} =
      transcript
      |> Transcript.changeset(%{status: status})
      |> Repo.update()

    transcript
  end

  defp insert_segments(transcript, documents) do
    documents
    |> Enum.flat_map(&Map.get(&1, "transcription", []))
    |> Enum.each(&insert_segment(transcript, &1))
  end

  defp insert_segment(transcript, segment) do
    text = segment |> Map.get("text", "") |> String.trim()

    %Segment{}
    |> Segment.changeset(%{
      transcript_id: transcript.id,
      text: text,
      machine_text: text,
      start_offset: get_in(segment, ["offsets", "from"]) || 0,
      end_offset: get_in(segment, ["offsets", "to"]) || 0
    })
    |> Repo.insert!()
  end

  defp broadcast(transcript, recording_id) do
    Phoenix.PubSub.broadcast(
      EarWitness.PubSub,
      "transcription:#{recording_id}",
      {:transcription_status, transcript.status}
    )

    transcript
  end
end
