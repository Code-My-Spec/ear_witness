defmodule EarWitness.Recordings.Collection do
  @moduledoc """
  A case/matter/meeting grouping recordings. Deleting a collection never
  deletes its member recordings.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias EarWitness.Recordings.Recording

  schema "collections" do
    field(:name, :string)
    field(:date, :date)
    field(:participants, :string)

    many_to_many(:recordings, Recording, join_through: "recording_collections")

    timestamps()
  end

  def changeset(collection, attrs) do
    collection
    |> cast(attrs, [:name, :date, :participants])
    |> validate_required([:name])
  end
end
