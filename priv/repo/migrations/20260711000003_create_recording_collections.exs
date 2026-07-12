defmodule EarWitness.Repo.Migrations.CreateRecordingCollections do
  use Ecto.Migration

  def change do
    create table(:recording_collections) do
      add(:recording_id, references(:recordings, on_delete: :delete_all), null: false)
      add(:collection_id, references(:collections, on_delete: :delete_all), null: false)
    end

    create(unique_index(:recording_collections, [:recording_id, :collection_id]))
    create(index(:recording_collections, [:collection_id]))
  end
end
