defmodule EarWitness.Transcription do
  @moduledoc """
  On-device transcription of recordings. Runs transcription as a durable
  background job (Oban) and stores the resulting transcript with
  timestamped segments for display.
  """

  import Ecto.Query

  alias EarWitness.Recordings.Recording
  alias EarWitness.Repo
  alias EarWitness.Search
  alias EarWitness.Transcription.{Segment, Transcript, Worker}

  @doc """
  Starts transcription for a recording as a durable background job. Safe
  to call once per recording — reopening a recording that already has a
  transcript never re-queues work.
  """
  @spec transcribe(Recording.t()) :: {:ok, Transcript.t()} | {:error, Ecto.Changeset.t()}
  def transcribe(%Recording{id: id}) do
    case get_transcript_for_recording(id) do
      {:ok, %Transcript{status: :failed} = transcript} ->
        # Explicit user retry after a failure (e.g. an engine crash) —
        # re-enqueue rather than returning the dead transcript.
        with {:ok, _} <- transcript |> Transcript.changeset(%{status: :queued}) |> Repo.update(),
             {:ok, _job} <- %{recording_id: id} |> Worker.new() |> Oban.insert() do
          get_transcript_for_recording(id)
        end

      {:ok, transcript} ->
        {:ok, transcript}

      {:error, :not_found} ->
        with {:ok, _transcript} <-
               %Transcript{}
               |> Transcript.changeset(%{recording_id: id, status: :queued})
               |> Repo.insert(),
             {:ok, _job} <- %{recording_id: id} |> Worker.new() |> Oban.insert() do
          get_transcript_for_recording(id)
        end
    end
  end

  @doc "Fetches the transcript for a recording, with segments loaded in playback order."
  @spec get_transcript_for_recording(integer()) :: {:ok, Transcript.t()} | {:error, :not_found}
  def get_transcript_for_recording(recording_id) do
    ordered_segments = from(s in Segment, order_by: s.start_offset)

    Transcript
    |> Repo.get_by(recording_id: recording_id)
    |> case do
      nil -> {:error, :not_found}
      transcript -> {:ok, Repo.preload(transcript, segments: ordered_segments)}
    end
  end

  @doc "Subscribes the caller to status updates for one recording's transcription job."
  @spec subscribe(integer()) :: :ok
  def subscribe(recording_id) do
    Phoenix.PubSub.subscribe(EarWitness.PubSub, topic(recording_id))
  end

  @doc """
  Broadcasts a `{:transcription_status, status}` message to `subscribe/1`
  listeners for a recording — the same shape the Oban worker emits, so the
  recording view re-renders identically whether transcription ran in the
  background or streamed in live.
  """
  @spec broadcast_status(integer(), atom()) :: :ok
  def broadcast_status(recording_id, status) do
    Phoenix.PubSub.broadcast(
      EarWitness.PubSub,
      topic(recording_id),
      {:transcription_status, status}
    )
  end

  @doc """
  Creates the transcript row for a live capture in the `:transcribing` state.
  `EarWitness.Transcription.LiveTranscriber` appends segments to it as the
  capture is transcribed in real time; it moves to `:completed` once the
  backlog is finished on stop. Safe to read via `get_transcript_for_recording/1`
  at any point — segments are returned regardless of status.
  """
  @spec create_live_transcript(integer()) :: {:ok, Transcript.t()} | {:error, Ecto.Changeset.t()}
  def create_live_transcript(recording_id) do
    %Transcript{}
    |> Transcript.changeset(%{recording_id: recording_id, status: :transcribing})
    |> Repo.insert()
  end

  @doc """
  Appends one finalized live segment to a transcript, with no speaker
  attribution — diarization is post-hoc and runs once on stop (story 872:
  no speaker labels during recording). `attrs` carries `:text`,
  `:start_offset`, and `:end_offset` (absolute milliseconds from the start of
  the recording).
  """
  @spec append_segment(integer(), %{
          text: String.t(),
          start_offset: non_neg_integer(),
          end_offset: non_neg_integer()
        }) :: {:ok, Segment.t()} | {:error, Ecto.Changeset.t()}
  def append_segment(transcript_id, %{text: text} = attrs) do
    %Segment{}
    |> Segment.changeset(%{
      transcript_id: transcript_id,
      text: text,
      machine_text: text,
      start_offset: attrs.start_offset,
      end_offset: attrs.end_offset
    })
    |> Repo.insert()
  end

  @doc "Marks a live transcript complete once its backlog is fully transcribed."
  @spec complete_transcript(integer()) :: {:ok, Transcript.t()} | {:error, Ecto.Changeset.t()}
  def complete_transcript(transcript_id) do
    Transcript
    |> Repo.get!(transcript_id)
    |> Transcript.changeset(%{status: :completed})
    |> Repo.update()
  end

  @doc """
  Fetches the transcript a segment belongs to, with segments loaded in
  playback order. Backs `EarWitness.Search.reindex_segment/1`, which
  needs the owning recording and the transcript's full speaker roster to
  re-resolve the segment's display name.
  """
  @spec get_transcript_for_segment(Segment.t()) :: {:ok, Transcript.t()} | {:error, :not_found}
  def get_transcript_for_segment(%Segment{transcript_id: transcript_id}) do
    ordered_segments = from(s in Segment, order_by: s.start_offset)

    Transcript
    |> Repo.get(transcript_id)
    |> case do
      nil -> {:error, :not_found}
      transcript -> {:ok, Repo.preload(transcript, segments: ordered_segments)}
    end
  end

  @doc """
  Corrects a segment's text inline, pushing its previous text onto its
  edit history so it can be undone or reverted later.
  """
  @spec update_segment_text(integer() | binary(), String.t()) ::
          {:ok, Segment.t()} | {:error, Ecto.Changeset.t()}
  def update_segment_text(segment_id, text) do
    segment = Repo.get!(Segment, segment_id)

    segment
    |> Segment.changeset(%{text: text, history: segment.history ++ [segment.text]})
    |> Repo.update()
    |> reindex()
  end

  @doc "Moves one segment to a different speaker, leaving every other segment untouched."
  @spec reassign_segment_speaker(integer() | binary(), integer() | binary()) ::
          {:ok, Segment.t()} | {:error, Ecto.Changeset.t()}
  def reassign_segment_speaker(segment_id, speaker_id) do
    Segment
    |> Repo.get!(segment_id)
    |> Segment.changeset(%{speaker_id: speaker_id})
    |> Repo.update()
    |> reindex()
  end

  @doc """
  Restores a segment straight back to the immutable machine-heard text,
  discarding all accumulated edit history at once.
  """
  @spec revert_segment(integer() | binary()) :: {:ok, Segment.t()} | {:error, Ecto.Changeset.t()}
  def revert_segment(segment_id) do
    segment = Repo.get!(Segment, segment_id)

    segment
    |> Segment.changeset(%{text: segment.machine_text, history: []})
    |> Repo.update()
    |> reindex()
  end

  @doc """
  Walks back the single most recent text edit anywhere on a transcript,
  one step at a time, regardless of which segment it touched.
  """
  @spec undo_last_edit(integer() | binary()) :: {:ok, Segment.t()} | {:error, :no_history}
  def undo_last_edit(transcript_id) do
    case most_recently_edited_segment(transcript_id) do
      nil -> {:error, :no_history}
      segment -> pop_history(segment)
    end
  end

  defp most_recently_edited_segment(transcript_id) do
    Repo.one(
      from(s in Segment,
        where: s.transcript_id == ^transcript_id and s.history != [],
        order_by: [desc: s.updated_at],
        limit: 1
      )
    )
  end

  defp pop_history(%Segment{history: history} = segment) do
    {previous_text, remaining_history} = List.pop_at(history, -1)

    segment
    |> Segment.changeset(%{text: previous_text, history: remaining_history})
    |> Repo.update()
    |> reindex()
  end

  defp reindex({:ok, segment} = result) do
    :ok = Search.reindex_segment(segment)
    result
  end

  defp reindex(error), do: error

  defp topic(recording_id), do: "transcription:#{recording_id}"
end
