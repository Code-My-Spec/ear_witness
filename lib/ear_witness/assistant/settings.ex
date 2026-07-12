defmodule EarWitness.Assistant.Settings do
  @moduledoc """
  Persisted assistant-access toggle — a singleton row, following the same
  pattern as `EarWitness.Audio.Settings`. Off (`:disabled`) on a fresh
  install; the MCP tool surface (`EarWitnessWeb.McpServer`) reads this on
  every call.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "assistant_settings" do
    field(:access, Ecto.Enum, values: [:enabled, :disabled], default: :disabled)

    timestamps()
  end

  def changeset(settings, attrs) do
    cast(settings, attrs, [:access])
  end
end
