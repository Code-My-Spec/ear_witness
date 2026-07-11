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
end
