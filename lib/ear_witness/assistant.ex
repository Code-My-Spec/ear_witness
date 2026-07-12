defmodule EarWitness.Assistant do
  @moduledoc """
  Whether AI assistants may reach the local MCP tool surface
  (`EarWitnessWeb.McpServer`). Off by default, user-enabled in Settings,
  and instantly revocable — see the anubis-mcp ADR. Has no knowledge of
  MCP, tools, or transports; `EarWitnessWeb.McpServer` composes this
  context purely to check whether it should serve a call.
  """

  alias EarWitness.Assistant.Settings
  alias EarWitness.Repo

  @doc "Whether AI assistants may currently reach the MCP tool surface."
  @spec get_access() :: :enabled | :disabled
  def get_access, do: settings().access

  @doc "Persists whether AI assistants may reach the MCP tool surface."
  @spec set_access(:enabled | :disabled) :: {:ok, :enabled | :disabled}
  def set_access(access) when access in [:enabled, :disabled] do
    {:ok, updated} =
      settings()
      |> Settings.changeset(%{access: access})
      |> Repo.update()

    {:ok, updated.access}
  end

  defp settings do
    case Repo.all(Settings) do
      [] ->
        %Settings{}
        |> Settings.changeset(%{})
        |> Repo.insert!()

      [settings] ->
        settings
    end
  end
end
