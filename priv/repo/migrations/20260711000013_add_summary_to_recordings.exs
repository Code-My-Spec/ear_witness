defmodule EarWitness.Repo.Migrations.AddSummaryToRecordings do
  use Ecto.Migration

  def change do
    alter table(:recordings) do
      add(:summary, :string)
    end
  end
end
