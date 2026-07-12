defmodule EarWitness.Repo.Migrations.CreateModelSettings do
  use Ecto.Migration

  def change do
    create table(:model_settings) do
      add(:active_model_id, :string)

      timestamps()
    end
  end
end
