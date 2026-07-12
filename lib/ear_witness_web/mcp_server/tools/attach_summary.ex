defmodule EarWitnessWeb.McpServer.Tools.AttachSummary do
  @moduledoc """
  Attaches a summary/note to a recording — the one write tool this
  surface allows. Anubis tool-component wrapper around
  `EarWitnessWeb.McpServer.attach_summary/1` — the actual access gating
  and persistence logic live there; this module only translates between
  the MCP wire shapes and that function.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.MCP.Error
  alias Anubis.Server.Response
  alias EarWitnessWeb.McpServer

  schema do
    field(:recording_id, :string, required: true, description: "The recording to summarize.")
    field(:summary, :string, required: true, description: "The summary or note to save.")
  end

  @impl true
  def execute(%{recording_id: recording_id, summary: summary}, frame) do
    case McpServer.attach_summary(%{"recording_id" => recording_id, "summary" => summary}) do
      {:ok, result} ->
        {:reply, Response.json(Response.tool(), result), frame}

      {:error, :access_revoked} ->
        {:error, Error.execution("assistant access has been revoked"), frame}
    end
  end
end
