defmodule EarWitness.Repo do
  use Ecto.Repo, otp_app: :ear_witness, adapter: Ecto.Adapters.SQLite3

  def initialize() do
    Ecto.Adapters.SQL.query!(__MODULE__, """
        CREATE TABLE IF NOT EXISTS todos (
          id INTEGER PRIMARY KEY,
          text TEXT,
          status TEXT
        )
    """)
  end

  @doc """
  Runs any pending Ecto migrations from `priv/repo/migrations`.

  A packaged desktop app has no `mix ecto.migrate` step, so the schema
  (`local_settings`, `oban_jobs`, …) must be brought up in-process at boot,
  against the user's local SQLite database. The Repo must already be started.
  """
  def migrate() do
    path = Application.app_dir(:ear_witness, "priv/repo/migrations")
    Ecto.Migrator.run(__MODULE__, path, :up, all: true)
  end
end
