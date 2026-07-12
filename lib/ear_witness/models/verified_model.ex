defmodule EarWitness.Models.VerifiedModel do
  @moduledoc """
  One row per model id whose download has completed and checksum-verified
  — the durable record `EarWitness.Models.downloaded?/1` checks. Durable
  (survives an app restart) and, in tests, rolled back by the Ecto
  Sandbox between tests — unlike `EarWitness.Models.Downloader`'s
  in-memory progress map, which is a single process shared by every test
  in a suite run.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "verified_models" do
    field(:model_id, :string)

    timestamps()
  end

  def changeset(verified_model, attrs) do
    verified_model
    |> cast(attrs, [:model_id])
    |> validate_required([:model_id])
    |> unique_constraint(:model_id)
  end
end
