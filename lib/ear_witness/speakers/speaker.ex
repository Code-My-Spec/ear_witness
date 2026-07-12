defmodule EarWitness.Speakers.Speaker do
  @moduledoc """
  A named person with a voice signature (embedding centroid) accumulated
  across recordings. Named speakers get their chosen name; unnamed
  speakers display as "Speaker N" (computed by
  `EarWitness.Speakers.label/2`, not stored).
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "speakers" do
    field(:name, :string)
    field(:color, :string)

    timestamps()
  end

  def changeset(speaker, attrs) do
    cast(speaker, attrs, [:name, :color])
  end
end
