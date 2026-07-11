defmodule EarWitness.LocalSettings do
  @moduledoc """
    Repo for our EarWitness. Minimal data structure for a todo item.
  """
  use Ecto.Schema
  alias EarWitness.Repo
  import Ecto.Changeset

  schema "local_settings" do
    field(:input, :integer)
    field(:output, :integer)
    timestamps()
  end

  @topic "settings"
  def get_local_settings() do
    Repo.all(__MODULE__)
    |> case do
      [] ->
        cast(%__MODULE__{}, %{}, [:input, :output])
        |> Repo.insert!()

      [settings] ->
        settings
    end
  end

  def update_local_settings(attrs) do
    settings =
      get_local_settings()
      |> cast(attrs, [:input, :output])
      |> Repo.update!()

    Phoenix.PubSub.broadcast(EarWitness.PubSub, @topic, settings)

    settings
  end

  def subscribe() do
    Phoenix.PubSub.subscribe(EarWitness.PubSub, @topic)
  end
end
