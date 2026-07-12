defmodule EarWitnessSpex.LetMyAiAssistantWorkMyConversations.Criterion7382Spex do
  @moduledoc """
  Story 868 — Let my AI assistant work my conversations
  Criterion 7382: No network listener for the MCP surface

  The anubis-mcp ADR makes this guarantee structural rather than
  configured: EarWitness runs Anubis over its **stdio** transport, so
  Claude Code (or any MCP client) launches/attaches to the server as a
  local subprocess exchanging JSON-RPC over stdin/stdout — there is no
  Cowboy/Plug endpoint, port, or socket opened for MCP at all, unlike the
  app's own Phoenix web endpoint (which serves the LiveView UI, a
  different, pre-existing listener this story doesn't touch). Nothing in
  the transcription/search/speakers contexts the MCP tools call takes an
  HTTP client dependency either (same structural argument the "networking
  disabled" transcription spec, story 860 criterion 7326, already makes),
  so there's no path by which an MCP tool call could open one.

  This can't be honestly proven by a spec faking a network probe (there's
  nothing to dial — that's the point), so this asserts the one thing the
  app's own state actually exposes: the MCP surface's transport
  configuration reads `:stdio`, with no port configured for it. That's an
  in-app-observable fact, not a simulated one — see the story's assigned
  task for why this is the sanctioned exception to driving the surface
  itself.
  """

  use EarWitnessSpex.Case

  spex "No network listener for the MCP surface" do
    scenario "engineer checks how the MCP surface is wired up", context do
      given_ "EarWitness is running with its default configuration", context do
        context
      end

      when_ "the MCP surface's transport configuration is inspected", context do
        config = Application.get_env(:ear_witness, EarWitnessWeb.McpServer, [])
        Map.put(context, :mcp_config, config)
      end

      then_ "it specifies the stdio transport, with no network port configured for MCP",
            context do
        assert Keyword.get(context.mcp_config, :transport) == :stdio
        refute Keyword.has_key?(context.mcp_config, :port)

        :ok
      end
    end
  end
end
