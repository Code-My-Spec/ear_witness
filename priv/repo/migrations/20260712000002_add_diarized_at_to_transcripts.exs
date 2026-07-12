defmodule EarWitness.Repo.Migrations.AddDiarizedAtToTranscripts do
  use Ecto.Migration

  def change do
    alter table(:transcripts) do
      add(:diarized_at, :utc_datetime)
    end
  end
end
