defmodule EarWitness.Repo.Migrations.SearchDropPorterStemming do
  use Ecto.Migration

  # FTS5 virtual tables are raw SQLite DDL, so up/0 and down/0 spell out
  # both directions explicitly.
  #
  # Rebuilds both search indexes to tokenize with `unicode61` only,
  # dropping the `porter` stemmer. Porter stemmed "witness" to the stem
  # "wit"; combined with the query layer's trailing prefix wildcard that
  # became "wit*", which matched the common word "with" (issue 4116ef93 —
  # searching "witness" surfaced unrelated "with" segments). Prefix
  # matching alone still finds forward inflections ("meeting" -> "meetings"),
  # so recall for as-you-type search is preserved without the false
  # positives that surprised users.
  #
  # The FTS content columns are retained verbatim across the rebuild by
  # snapshotting the existing rows, so no application-level reindex is
  # required.

  def up do
    rebuild(tokenize: "unicode61")
  end

  def down do
    rebuild(tokenize: "porter unicode61")
  end

  defp rebuild(tokenize: tokenize) do
    execute(
      "CREATE TEMP TABLE _seg_backup AS SELECT segment_id, recording_id, speaker, timestamp, text FROM search_segments"
    )

    execute(
      "CREATE TEMP TABLE _rec_backup AS SELECT recording_id, title, collection, participants FROM search_recordings"
    )

    execute("DROP TABLE search_segments")
    execute("DROP TABLE search_recordings")

    execute("""
    CREATE VIRTUAL TABLE search_segments USING fts5(
      segment_id UNINDEXED,
      recording_id UNINDEXED,
      speaker UNINDEXED,
      timestamp UNINDEXED,
      text,
      tokenize = '#{tokenize}'
    )
    """)

    execute("""
    CREATE VIRTUAL TABLE search_recordings USING fts5(
      recording_id UNINDEXED,
      title,
      collection,
      participants,
      tokenize = '#{tokenize}'
    )
    """)

    execute(
      "INSERT INTO search_segments (segment_id, recording_id, speaker, timestamp, text) SELECT segment_id, recording_id, speaker, timestamp, text FROM _seg_backup"
    )

    execute(
      "INSERT INTO search_recordings (recording_id, title, collection, participants) SELECT recording_id, title, collection, participants FROM _rec_backup"
    )

    execute("DROP TABLE _seg_backup")
    execute("DROP TABLE _rec_backup")
  end
end
