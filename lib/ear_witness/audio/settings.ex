defmodule EarWitness.Audio.Settings do
  @moduledoc """
  Persisted capture settings — a singleton row, following the same
  pattern as `EarWitness.LocalSettings`. There is exactly one machine's
  worth of settings, not one per user.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "audio_settings" do
    field(:active_capture_source, Ecto.Enum,
      values: [:microphone, :system_audio_tap],
      default: :microphone
    )

    field(:consent_policy, Ecto.Enum, values: [:silent, :notify, :announce], default: :notify)

    timestamps()
  end

  def changeset(settings, attrs) do
    cast(settings, attrs, [:active_capture_source, :consent_policy])
  end
end
