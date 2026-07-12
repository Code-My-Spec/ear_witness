defmodule EarWitness.Repo.Migrations.CreateAssistantSettings do
  use Ecto.Migration

  def change do
    create table(:assistant_settings) do
      add(:access, :string, null: false, default: "disabled")

      timestamps()
    end
  end
end
