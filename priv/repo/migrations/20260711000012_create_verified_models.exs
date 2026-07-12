defmodule EarWitness.Repo.Migrations.CreateVerifiedModels do
  use Ecto.Migration

  def change do
    create table(:verified_models) do
      add(:model_id, :string, null: false)

      timestamps()
    end

    create(unique_index(:verified_models, [:model_id]))
  end
end
