defmodule EarWitness.Repo.Migrations.CreateCollections do
  use Ecto.Migration

  def change do
    create table(:collections) do
      add(:name, :string, null: false)
      add(:date, :date)
      add(:participants, :string)

      timestamps()
    end
  end
end
