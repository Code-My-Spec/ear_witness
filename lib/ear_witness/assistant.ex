defmodule EarWitness.Assistant do
  @moduledoc """
  Whether AI assistants may reach the local MCP tool surface
  (`EarWitnessWeb.McpServer`). Off by default, user-enabled in Settings,
  and instantly revocable — see the anubis-mcp ADR. Has no knowledge of
  MCP, tools, or transports; `EarWitnessWeb.McpServer` composes this
  context purely to check whether it should serve a call.
  """

  import Ecto.Query
  alias EarWitness.Assistant.Settings
  alias EarWitness.Repo

  @doc "Whether AI assistants may currently reach the MCP tool surface."
  @spec get_access() :: :enabled | :disabled
  def get_access, do: read_settings().access

  @doc "Persists whether AI assistants may reach the MCP tool surface."
  @spec set_access(:enabled | :disabled) :: {:ok, :enabled | :disabled}
  def set_access(access) when access in [:enabled, :disabled] do
    {:ok, updated} =
      settings()
      |> Settings.changeset(%{access: access})
      |> Repo.update()

    {:ok, updated.access}
  end

  # Read-only accessor: NEVER writes. Returns the singleton row or an
  # unpersisted %Settings{} (access defaults :disabled — off by default).
  # get_access is checked on every MCP tool call, so it must not write.
  defp read_settings do
    case Repo.all(from(s in Settings, order_by: s.id, limit: 1)) do
      [settings | _] -> settings
      [] -> %Settings{}
    end
  end

  # Get-or-create for WRITES only (set_access needs a persisted row).
  # Tolerate the concurrent-insert race by always using the lowest-id row and
  # pruning duplicates (see EarWitness.Models.settings/0).
  defp settings do
    case Repo.all(from(s in Settings, order_by: s.id)) do
      [] ->
        # Unique-index-guarded singleton (see EarWitness.Models.settings/0);
        # a race-lost insert no-ops and we re-read the winner.
        %Settings{} |> Settings.changeset(%{}) |> Repo.insert!(on_conflict: :nothing)
        Repo.one!(from(s in Settings, order_by: s.id, limit: 1))

      [settings | _] ->
        settings
    end
  end
end
