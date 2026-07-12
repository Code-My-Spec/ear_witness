defmodule EarWitness.Repo.Migrations.CreateRecordings do
  use Ecto.Migration

  def change do
    create table(:recordings) do
      add(:title, :string, null: false)
      add(:source, :string, null: false)
      add(:file_path, :string, null: false)
      add(:duration, :float, null: false)
      add(:status, :string, null: false, default: "active")
      add(:trashed_at, :utc_datetime)
      add(:date, :date)
      add(:participants, :string)

      timestamps()
    end

    create(index(:recordings, [:status]))
  end
end
