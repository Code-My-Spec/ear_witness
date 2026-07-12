defmodule EarWitness.Repo.Migrations.CreateSearchIndex do
  use Ecto.Migration

  # FTS5 virtual tables are raw SQLite DDL with no structured Ecto
  # representation, so `change/0` (which needs to auto-derive its
  # reverse) doesn't apply — `up/0`/`down/0` spell out both directions.
  def up do
    execute("""
    CREATE VIRTUAL TABLE search_segments USING fts5(
      segment_id UNINDEXED,
      recording_id UNINDEXED,
      speaker UNINDEXED,
      timestamp UNINDEXED,
      text,
      tokenize = 'porter unicode61'
    )
    """)

    execute("""
    CREATE VIRTUAL TABLE search_recordings USING fts5(
      recording_id UNINDEXED,
      title,
      collection,
      participants,
      tokenize = 'porter unicode61'
    )
    """)
  end

  def down do
    execute("DROP TABLE IF EXISTS search_recordings")
    execute("DROP TABLE IF EXISTS search_segments")
  end
end
