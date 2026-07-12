defmodule EarWitnessWeb.McpServer.Server do
  @moduledoc """
  The Anubis MCP server process — registers the sanctioned tool surface
  (`EarWitnessWeb.McpServer.Tools.*`) and is meant to be started with
  `transport: :stdio` only (see the anubis-mcp ADR and
  `EarWitnessWeb.McpServer`'s moduledoc). No network transport is ever
  configured for it.

  Started by `EarWitnessWeb.Application` **only** when the app is launched
  as a stdio MCP subprocess — i.e. an AI assistant's client spawns the
  EarWitness binary with `EARWITNESS_MCP_STDIO=1`. In that mode the app
  boots just Repo + this server over stdin/stdout, no Phoenix endpoint and
  no desktop window (see `EarWitnessWeb.Application.start/2` and
  `priv/mcp/earwitness.mcp.json.example`). A normal GUI/test/QA boot leaves
  that env var unset and never starts the stdio transport, because Anubis's
  stdio transport `{:stop, :normal}`s on stdin EOF and a boot with no
  attached client has dead stdin.

  The tool functions themselves (`EarWitnessWeb.McpServer.list_tools/0`
  and friends) also work standalone, without this process running — that
  is what the story 868 specs drive directly.
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
