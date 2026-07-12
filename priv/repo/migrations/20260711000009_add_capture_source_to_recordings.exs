defmodule EarWitness.Repo.Migrations.AddCaptureSourceToRecordings do
  use Ecto.Migration

  def change do
    alter table(:recordings) do
      add(:capture_source, :string)
    end
  end
end
