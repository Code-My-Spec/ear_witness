defmodule EarWitness.Models.ModelSettings do
  @moduledoc """
  Persisted active-model selection — a singleton row, following the same
  pattern as `EarWitness.Audio.Settings`. `active_model_id` is `nil` on a
  fresh install (no model chosen yet).
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "model_settings" do
    field(:active_model_id, :string)

    timestamps()
  end

  def changeset(settings, attrs) do
    cast(settings, attrs, [:active_model_id])
  end
end
