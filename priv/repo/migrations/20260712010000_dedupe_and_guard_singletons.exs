defmodule EarWitness.Repo.Migrations.DedupeAndGuardSingletons do
  use Ecto.Migration

  @singletons ~w(model_settings audio_settings assistant_settings)

  # These tables each hold exactly one settings row, but the read-time
  # "insert if empty" pattern could race two inserts in (story-860 QA found
  # model_settings with two rows, 500ing every page). Collapse any existing
  # duplicates to the lowest id, then add a partial unique index on a
  # constant so a second row can never be inserted again.
  def up do
    for table <- @singletons do
      execute("DELETE FROM #{table} WHERE id NOT IN (SELECT MIN(id) FROM #{table})")
      execute("CREATE UNIQUE INDEX #{table}_singleton ON #{table} ((1))")
    end
  end

  def down do
    for table <- @singletons do
      execute("DROP INDEX IF EXISTS #{table}_singleton")
    end
  end
end
