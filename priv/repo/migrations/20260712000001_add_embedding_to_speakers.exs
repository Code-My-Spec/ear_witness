defmodule EarWitness.Repo.Migrations.AddEmbeddingToSpeakers do
  use Ecto.Migration

  def change do
    alter table(:speakers) do
      add(:embedding, {:array, :float})
    end
  end
end
