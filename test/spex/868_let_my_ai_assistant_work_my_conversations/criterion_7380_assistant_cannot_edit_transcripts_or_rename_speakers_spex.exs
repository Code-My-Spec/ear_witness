defmodule EarWitnessSpex.LetMyAiAssistantWorkMyConversations.Criterion7380Spex do
  @moduledoc """
  Story 868 — Let my AI assistant work my conversations
  Criterion 7380: Assistant cannot edit transcripts or rename speakers

  The anubis-mcp ADR scopes the MCP surface to read tools plus a single
  write tool (attach-summary) — no transcript-editing or speaker-renaming
  tool exists at all. This is asserted structurally, on the enumerated
  tool list the server hands back (mirroring criterion 7377's `tools/list`
  call): the set of tool names is exactly the sanctioned read/write set,
  and none of them touch editing or renaming — not by driving
  `EarWitnessWeb.TranscriptLive.Editor` and hoping it 403s, which would
  test the wrong surface for an MCP client that has no LiveView session at
  all.
  """

  use EarWitnessSpex.Case

  spex "Assistant cannot edit transcripts or rename speakers" do
    scenario "assistant lists the tools and finds no way to edit a transcript or rename a speaker",
             context do
      given_ "assistant access is enabled", context do
        EarWitnessSpex.SettingsSteps.set_assistant_access(context.conn, "enabled")
        context
      end

      when_ "the assistant lists every tool the server exposes", context do
        result = EarWitnessWeb.McpServer.list_tools()
        Map.put(context, :result, result)
      end

      then_ "no transcript-edit or speaker-rename tool is offered, only the sanctioned read/write set",
            context do
        assert {:ok, tools} = context.result
        names = tools |> Enum.map(& &1.name) |> MapSet.new()

        assert names == MapSet.new(["search_transcripts", "read_transcript", "attach_summary"])
        refute Enum.any?(names, &String.contains?(&1, "edit"))
        refute Enum.any?(names, &String.contains?(&1, "rename"))
        refute Enum.any?(names, &String.contains?(&1, "delete"))

        :ok
      end
    end
  end
end
