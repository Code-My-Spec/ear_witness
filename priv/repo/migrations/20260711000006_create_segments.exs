defmodule EarWitness.Repo.Migrations.CreateSegments do
  use Ecto.Migration

  def change do
    create table(:segments) do
      add(:transcript_id, references(:transcripts, on_delete: :delete_all), null: false)
      add(:text, :text, null: false)
      add(:machine_text, :text, null: false)
      add(:start_offset, :integer, null: false)
      add(:end_offset, :integer, null: false)
      add(:speaker_id, :integer)
      add(:history, {:array, :string}, null: false, default: [])

      timestamps()
    end

    create(index(:segments, [:transcript_id]))
  end
end
