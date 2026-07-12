defmodule EarWitnessWeb.McpServer.Tools.ReadTranscript do
  @moduledoc """
  Reads one recording's full transcript, segment by segment, plus its
  attached summary. Anubis tool-component wrapper around
  `EarWitnessWeb.McpServer.read_transcript/1` — the actual access gating
  and lookup logic live there; this module only translates between the
  MCP wire shapes and that function.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.MCP.Error
  alias Anubis.Server.Response
  alias EarWitnessWeb.McpServer

  schema do
    field(:recording_id, :string, required: true, description: "The recording to read.")
  end

  @impl true
  def execute(%{recording_id: recording_id}, frame) do
    case McpServer.read_transcript(%{"recording_id" => recording_id}) do
      {:ok, result} ->
        {:reply, Response.json(Response.tool(), result), frame}

      {:error, :access_revoked} ->
        {:error, Error.execution("assistant access has been revoked"), frame}
    end
  end
end
