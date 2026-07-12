defmodule EarWitnessWeb.McpServer.Tools.SearchTranscripts do
  @moduledoc """
  Full-text search over the transcript library. Anubis tool-component
  wrapper around `EarWitnessWeb.McpServer.search_transcripts/1` — the
  actual access gating and search logic live there; this module only
  translates between the MCP wire shapes and that function.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.MCP.Error
  alias Anubis.Server.Response
  alias EarWitnessWeb.McpServer

  schema do
    field(:query, :string, required: true, description: "Text to search for across transcripts.")
  end

  @impl true
  def execute(%{query: query}, frame) do
    case McpServer.search_transcripts(%{"query" => query}) do
      {:ok, result} ->
        {:reply, Response.json(Response.tool(), result), frame}

      {:error, :access_revoked} ->
        {:error, Error.execution("assistant access has been revoked"), frame}
    end
  end
end
