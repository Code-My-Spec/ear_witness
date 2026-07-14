defmodule EarWitness.Search.Index do
  @moduledoc """
  The SQLite FTS5-backed store behind `EarWitness.Search`: owns the FTS5
  virtual tables (`search_segments`, `search_recordings`) and raw MATCH
  query execution. The parent context owns shaping these raw rows into
  `segment_hit`/`recording_hit` structs.

  Neither `upsert_segment/1` nor `upsert_recording/1` is given a date, so
  date-range filtering in `query/2` reads a recording's `inserted_at`
  straight off the `recordings` table (by table name, the same
  raw-table-join convention `EarWitness.Recordings` itself already uses
  for `recording_collections`) rather than duplicating it into the index.
  """

  alias EarWitness.Repo

  @type segment_row :: %{
          type: :segment,
          segment_id: term(),
          recording_id: term(),
          speaker: String.t() | nil,
          timestamp: non_neg_integer(),
          text: String.t(),
          rank: float()
        }

  @type recording_row :: %{
          type: :recording,
          recording_id: term(),
          title: String.t(),
          collection: String.t() | nil,
          participants: [String.t()],
          matched_field: :title | :collection | :speaker,
          rank: float()
        }

  @doc """
  Writes or replaces one segment's indexed row — text, speaker, and
  timestamp, keyed by segment id and associated with its recording.
  """
  @spec upsert_segment(%{
          segment_id: term(),
          recording_id: term(),
          text: String.t(),
          speaker: String.t() | nil,
          timestamp: non_neg_integer()
        }) :: :ok
  def upsert_segment(%{
        segment_id: segment_id,
        recording_id: recording_id,
        text: text,
        speaker: speaker,
        timestamp: timestamp
      }) do
    delete_where!("search_segments", "segment_id", segment_id)

    exec!(
      "INSERT INTO search_segments (segment_id, recording_id, speaker, timestamp, text) VALUES (?, ?, ?, ?, ?)",
      [segment_id, recording_id, speaker, timestamp, text]
    )

    :ok
  end

  @doc """
  Writes or replaces one recording's indexed metadata — title, collection
  name, and collection participant names — keyed by recording id.
  """
  @spec upsert_recording(%{
          recording_id: term(),
          title: String.t(),
          collection: String.t() | nil,
          participants: [String.t()]
        }) :: :ok
  def upsert_recording(%{
        recording_id: recording_id,
        title: title,
        collection: collection,
        participants: participants
      }) do
    delete_where!("search_recordings", "recording_id", recording_id)

    exec!(
      "INSERT INTO search_recordings (recording_id, title, collection, participants) VALUES (?, ?, ?, ?)",
      [recording_id, title, collection || "", encode_participants(participants)]
    )

    :ok
  end

  @doc """
  Runs an FTS5 MATCH query against both the indexed segment text and the
  indexed recording metadata, with optional speaker and date-range
  filters, returning raw matching rows ranked by FTS5 relevance.
  """
  @spec query(String.t(), keyword()) :: [segment_row() | recording_row()]
  def query(match, opts \\ []) do
    fts_query = normalize_match(match)
    date_clause = date_clause(opts)

    (segment_rows(fts_query, opts, date_clause) ++ recording_rows(fts_query, opts, date_clause))
    |> Enum.sort_by(& &1.rank)
  end

  @doc """
  Distinct speaker labels present across every indexed segment — each speaker
  the app has actually attributed speech to (named speakers like "Tenant" AND
  the generic "Speaker N" labels), so the search speaker filter offers the
  speakers that really exist rather than only the named ones.
  """
  @spec list_speakers() :: [String.t()]
  def list_speakers do
    "SELECT DISTINCT speaker FROM search_segments WHERE speaker IS NOT NULL AND speaker != '' ORDER BY speaker"
    |> query!([])
    |> Enum.map(fn [speaker] -> speaker end)
  end

  # -- segment matches ------------------------------------------------------

  defp segment_rows(fts_query, opts, {date_sql, date_params}) do
    {speaker_sql, speaker_params} = speaker_clause(opts, "s")

    sql = """
    SELECT s.segment_id, s.recording_id, s.speaker, s.timestamp, s.text, s.rank
    FROM search_segments s
    JOIN recordings r ON r.id = s.recording_id
    WHERE s.text MATCH ?#{speaker_sql}#{date_sql}
    """

    query!(sql, [fts_query | speaker_params ++ date_params])
    |> Enum.map(&to_segment_row/1)
  end

  defp to_segment_row([segment_id, recording_id, speaker, timestamp, text, rank]) do
    %{
      type: :segment,
      segment_id: segment_id,
      recording_id: recording_id,
      speaker: speaker,
      timestamp: timestamp,
      text: text,
      rank: rank
    }
  end

  # -- recording matches -----------------------------------------------------

  @metadata_columns [
    {"title", "title"},
    {"collection", "collection"},
    {"participants", "speaker"}
  ]

  defp recording_rows(fts_query, opts, {date_sql, date_params}) do
    @metadata_columns
    |> Enum.flat_map(fn {column, tag} ->
      query!(metadata_sql(column, tag, date_sql), [fts_query | date_params])
    end)
    |> Enum.map(&to_recording_row/1)
    |> filter_by_speaker(opts)
  end

  defp metadata_sql(column, tag, date_sql) do
    """
    SELECT m.recording_id, m.title, m.collection, m.participants, '#{tag}', m.rank
    FROM search_recordings m
    JOIN recordings r ON r.id = m.recording_id
    WHERE m.#{column} MATCH ?#{date_sql}
    """
  end

  defp to_recording_row([recording_id, title, collection, participants, matched_field, rank]) do
    %{
      type: :recording,
      recording_id: recording_id,
      title: title,
      collection: nilify(collection),
      participants: decode_participants(participants),
      matched_field: matched_field_atom(matched_field),
      rank: rank
    }
  end

  defp matched_field_atom("title"), do: :title
  defp matched_field_atom("collection"), do: :collection
  defp matched_field_atom("speaker"), do: :speaker

  defp filter_by_speaker(rows, opts) do
    case Keyword.get(opts, :speaker) do
      nil -> rows
      speaker -> Enum.filter(rows, &(speaker in &1.participants))
    end
  end

  # -- shared filter clauses --------------------------------------------------

  defp speaker_clause(opts, column_alias) do
    build_speaker_clause(Keyword.get(opts, :speaker), column_alias)
  end

  defp build_speaker_clause(nil, _column_alias), do: {"", []}

  defp build_speaker_clause(speaker, column_alias),
    do: {" AND #{column_alias}.speaker = ?", [speaker]}

  defp date_clause(opts) do
    build_date_clause(Keyword.get(opts, :from), Keyword.get(opts, :to))
  end

  defp build_date_clause(nil, nil), do: {"", []}

  defp build_date_clause(from, nil),
    do: {" AND date(r.inserted_at) >= ?", [Date.to_iso8601(from)]}

  defp build_date_clause(nil, to),
    do: {" AND date(r.inserted_at) <= ?", [Date.to_iso8601(to)]}

  defp build_date_clause(from, to),
    do: {" AND date(r.inserted_at) BETWEEN ? AND ?", [Date.to_iso8601(from), Date.to_iso8601(to)]}

  # -- FTS5 MATCH normalization ------------------------------------------------

  defp normalize_match(query) do
    query
    |> String.split(~r/\s+/, trim: true)
    |> Enum.map_join(" ", &fts5_prefix_term/1)
  end

  defp fts5_prefix_term(word) do
    escaped = String.replace(word, "\"", "\"\"")
    ~s("#{escaped}"*)
  end

  # -- participants encoding ---------------------------------------------------

  defp encode_participants(names), do: Enum.join(names, "\n")

  defp decode_participants(nil), do: []
  defp decode_participants(""), do: []
  defp decode_participants(names), do: String.split(names, "\n", trim: true)

  defp nilify(""), do: nil
  defp nilify(value), do: value

  # -- raw SQL plumbing ---------------------------------------------------------

  defp delete_where!(table, column, value) do
    exec!("DELETE FROM #{table} WHERE #{column} = ?", [value])
  end

  defp exec!(sql, params) do
    Ecto.Adapters.SQL.query!(Repo, sql, params)
    :ok
  end

  defp query!(sql, params) do
    %{rows: rows} = Ecto.Adapters.SQL.query!(Repo, sql, params)
    rows
  end
end
