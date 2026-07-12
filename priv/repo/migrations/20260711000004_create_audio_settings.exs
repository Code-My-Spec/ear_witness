defmodule EarWitness.Repo.Migrations.CreateAudioSettings do
  use Ecto.Migration

  def change do
    create table(:audio_settings) do
      add(:active_capture_source, :string, null: false, default: "microphone")
      add(:consent_policy, :string, null: false, default: "notify")

      timestamps()
    end
  end
end
