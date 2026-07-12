defmodule EarWitness.Repo.Migrations.CreateSpeakers do
  use Ecto.Migration

  def change do
    create table(:speakers) do
      add(:name, :string)
      add(:color, :string)

      timestamps()
    end

    create(index(:segments, [:speaker_id]))
  end
end
