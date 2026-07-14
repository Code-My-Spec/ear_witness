defmodule EarWitness.Search do
  @moduledoc """
  Full-text search over the transcript library (SQLite FTS5) with speaker
  and date filters. Also the query surface the MCP tools call.
  """

  alias EarWitness.Recordings
  alias EarWitness.Recordings.Recording
  alias EarWitness.Search.Index
  alias EarWitness.Speakers
  alias EarWitness.Transcription
  alias EarWitness.Transcription.{Segment, Transcript}

  @type segment_hit :: %{
          type: :segment,
          recording_id: term(),
          recording_title: String.t(),
          segment_id: term(),
          speaker: String.t() | nil,
          timestamp: non_neg_integer(),
          snippet: String.t()
        }
  @type recording_hit :: %{
          type: :recording,
          recording_id: term(),
          recording_title: String.t(),
          matched_field: :title | :collection | :speaker,
          snippet: String.t()
        }

  @snippet_radius 60

  @doc """
  Full-text search across transcript segments and recording metadata
  (title, collection, speaker names), returning ranked hits with enough
  context to render without opening a recording.
  """
  @spec search(String.t(), keyword()) :: [segment_hit() | recording_hit()]
  def search(query, opts \\ []) do
    rows = Index.query(query, opts)
    titles = recording_titles(rows)

    Enum.map(rows, &build_hit(&1, query, titles))
  end

  @doc """
  Adds or refreshes a recording's title, collection name, and collection
  participant names in the index. Called whenever a recording is
  created, imported, or renamed, or its collection (including its
  participant list) changes.
  """
  @spec index_recording(Recording.t()) :: :ok
  @doc """
  Distinct speaker labels found across all transcripts — the set the /search
  speaker filter should offer (named speakers and generic "Speaker N" alike).
  """
  @spec list_speakers() :: [String.t()]
  def list_speakers, do: Index.list_speakers()

  def index_recording(%Recording{id: id}) do
    {:ok, %Recording{title: title, collections: collections}} = Recordings.get_recording(id)

    Index.upsert_recording(%{
      recording_id: id,
      title: title,
      collection: collection_name(collections),
      participants: collection_participants(collections)
    })
  end

  @doc """
  Indexes every segment of a finished transcript — text, speaker
  attribution, and timestamp. Called once transcription completes.
  """
  @spec index_transcript(Transcript.t()) :: :ok
  def index_transcript(%Transcript{segments: segments} = transcript) do
    Enum.each(segments, &index_segment(&1, transcript))
    :ok
  end

  @doc """
  Replaces one segment's indexed text and speaker after an inline
  correction or speaker reassignment.
  """
  @spec reindex_segment(Segment.t()) :: :ok
  def reindex_segment(%Segment{} = segment) do
    {:ok, transcript} = Transcription.get_transcript_for_segment(segment)
    index_segment(segment, transcript)
  end

  # -- indexing --------------------------------------------------------------

  defp index_segment(segment, transcript) do
    Index.upsert_segment(%{
      segment_id: segment.id,
      recording_id: transcript.recording_id,
      text: segment.text,
      speaker: speaker_name(segment.speaker_id, transcript),
      timestamp: segment.start_offset
    })
  end

  defp speaker_name(nil, _transcript), do: nil

  defp speaker_name(speaker_id, transcript) do
    speakers = Speakers.list_speakers_for_transcript(transcript)
    speaker = Enum.find(speakers, &(&1.id == speaker_id))
    index = Enum.find_index(speakers, &(&1.id == speaker_id)) || 0
    Speakers.label(speaker, index)
  end

  defp collection_name([]), do: nil
  defp collection_name([%{name: name} | _]), do: name

  defp collection_participants(collections) do
    collections
    |> Enum.flat_map(&participant_names(&1.participants))
    |> Enum.uniq()
  end

  defp participant_names(nil), do: []

  defp participant_names(participants) do
    participants |> String.split(",", trim: true) |> Enum.map(&String.trim/1)
  end

  # -- hit shaping -------------------------------------------------------------

  defp recording_titles(rows) do
    rows
    |> Enum.filter(&(&1.type == :segment))
    |> Enum.map(& &1.recording_id)
    |> Enum.uniq()
    |> Map.new(fn id ->
      {:ok, recording} = Recordings.get_recording(id)
      {id, recording.title}
    end)
  end

  defp build_hit(%{type: :segment} = row, query, titles) do
    %{
      type: :segment,
      recording_id: row.recording_id,
      recording_title: Map.fetch!(titles, row.recording_id),
      segment_id: row.segment_id,
      speaker: row.speaker,
      timestamp: row.timestamp,
      snippet: snippet(row.text, query)
    }
  end

  defp build_hit(%{type: :recording} = row, query, _titles) do
    %{
      type: :recording,
      recording_id: row.recording_id,
      recording_title: row.title,
      matched_field: row.matched_field,
      snippet: recording_snippet(row, query)
    }
  end

  defp recording_snippet(%{matched_field: :title, title: title}, _query), do: title

  defp recording_snippet(%{matched_field: :collection, collection: collection}, _query),
    do: collection

  defp recording_snippet(%{matched_field: :speaker, participants: participants}, query),
    do: matching_participant(participants, query)

  defp matching_participant([], _query), do: nil

  defp matching_participant(participants, query) do
    terms = query |> String.split(~r/\s+/, trim: true) |> Enum.map(&String.downcase/1)

    Enum.find(participants, List.first(participants), fn name ->
      downcased = String.downcase(name)
      Enum.any?(terms, &String.contains?(downcased, &1))
    end)
  end

  defp snippet(text, query) do
    query
    |> String.split(~r/\s+/, trim: true)
    |> Enum.find_value(&match_index(text, &1))
    |> window(text)
  end

  defp match_index(text, term) do
    case :binary.match(String.downcase(text), String.downcase(term)) do
      {index, _length} -> index
      :nomatch -> nil
    end
  end

  defp window(nil, text), do: String.slice(text, 0, @snippet_radius * 2)

  defp window(index, text) do
    from = max(index - @snippet_radius, 0)
    length = min(String.length(text) - from, @snippet_radius * 2)
    String.slice(text, from, length)
  end
end
