defmodule EarWitnessWeb.McpServer.Server do
  @moduledoc """
  The Anubis MCP server process — registers the sanctioned tool surface
  (`EarWitnessWeb.McpServer.Tools.*`) and is meant to be started with
  `transport: :stdio` only (see the anubis-mcp ADR and
  `EarWitnessWeb.McpServer`'s moduledoc). No network transport is ever
  configured for it.

  Not started by `EarWitnessWeb.Application` yet: the desktop app's own
  stdin/stdout aren't a terminal an MCP client can attach to the way a
  `mix run` or release entry point's are, so wiring this into the
  standard supervision tree needs a dedicated launch path (a release
  command / escript) rather than piggybacking on the GUI app's boot.
  Until that lands, start it explicitly for manual/QA verification:

      Application.ensure_all_started(:ear_witness)
      {:ok, _pid} = EarWitnessWeb.McpServer.Server.start_link(transport: :stdio)

  The tool functions themselves (`EarWitnessWeb.McpServer.list_tools/0`
  and friends) work standalone, without this process running — that is
  what the story 868 specs drive directly.
  """

  # Version is a literal, not `Mix.Project.config()[:version]` — this lib
  # module has no business depending on Mix being loaded at runtime (it
  # isn't, in a release). Keep in sync with `@version` in mix.exs.
  use Anubis.Server,
    name: "ear_witness",
    version: "1.2.0",
    capabilities: [:tools]

  component(EarWitnessWeb.McpServer.Tools.SearchTranscripts)
  component(EarWitnessWeb.McpServer.Tools.ReadTranscript)
  component(EarWitnessWeb.McpServer.Tools.AttachSummary)

  @impl true
  def init(_client_info, frame), do: {:ok, frame}
end
