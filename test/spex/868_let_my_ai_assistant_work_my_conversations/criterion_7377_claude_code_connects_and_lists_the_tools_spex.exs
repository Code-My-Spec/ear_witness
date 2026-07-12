defmodule EarWitnessSpex.LetMyAiAssistantWorkMyConversations.Criterion7377Spex do
  @moduledoc """
  Story 868 — Let my AI assistant work my conversations
  Criterion 7377: Claude Code connects and lists the tools

  The MCP tool surface (`EarWitnessWeb.McpServer`, Anubis over stdio — see
  the anubis-mcp ADR) is a sanctioned direct-call surface for specs (unlike
  `EarWitness.*` contexts): a spec drives it exactly the way an MCP client
  drives it, calling the server's tool functions and asserting on the
  result tuples, rather than opening an HTTP connection or a LiveView.

  Judgment call made explicit here (neither `EarWitnessWeb.McpServer` nor
  `EarWitnessWeb.SettingsLive` exists yet): `list_tools/0` returns
  `{:ok, tools}` where each tool is a map carrying at least a `:name`
  string, mirroring the MCP protocol's `tools/list` response — and the
  three tools an assistant needs (search, read, attach-summary) are named
  `"search_transcripts"`, `"read_transcript"`, `"attach_summary"`. A human
  should confirm these names/shapes before implementation.
  """

  use EarWitnessSpex.Case

  spex "Claude Code connects and lists the tools" do
    scenario "the user connects Claude Code to their local EarWitness library", context do
      given_ "the user has enabled assistant access in settings", context do
        view = EarWitnessSpex.SettingsSteps.set_assistant_access(context.conn, "enabled")
        Map.put(context, :settings_view, view)
      end

      when_ "Claude Code connects over stdio and asks for the available tools", context do
        result = EarWitnessWeb.McpServer.list_tools()
        Map.put(context, :result, result)
      end

      then_ "it sees the read and write tools it needs to work the conversation library",
            context do
        assert {:ok, tools} = context.result
        assert is_list(tools)
        assert tools != []

        names = Enum.map(tools, & &1.name)

        assert "search_transcripts" in names
        assert "read_transcript" in names
        assert "attach_summary" in names

        :ok
      end
    end
  end
end
