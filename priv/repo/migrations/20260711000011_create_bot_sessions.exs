defmodule EarWitness.Repo.Migrations.CreateBotSessions do
  use Ecto.Migration

  def change do
    create table(:bot_sessions) do
      add(:meeting_url, :string, null: false)
      add(:display_name, :string, null: false, default: "EarWitness Notetaker")
      add(:status, :string, null: false, default: "dispatched")
      add(:scheduled_at, :utc_datetime)
      add(:failure_reason, :string)
      add(:recording_id, references(:recordings))

      timestamps()
    end

    create(index(:bot_sessions, [:status]))
  end
end
