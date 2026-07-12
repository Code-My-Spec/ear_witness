defmodule EarWitnessSpex.LetMyAiAssistantWorkMyConversations.Criterion7381Spex do
  @moduledoc """
  Story 868 — Let my AI assistant work my conversations
  Criterion 7381: Revoking access shuts the assistant out

  "Access is user-enabled and revocable" (anubis-mcp ADR). This drives the
  revoke through the real settings UI (never `Application.put_env`, per
  the project BDD plan's anti-patterns) and then calls the MCP tool
  surface directly — the way a still-connected assistant would keep trying
  — asserting the calls are now rejected rather than served.

  Judgment call made explicit here: a rejected tool call returns
  `{:error, :access_revoked}`, distinct from any other tool-specific error
  shape, so the implementer has an unambiguous reason to check for.
  """

  use EarWitnessSpex.Case

  spex "Revoking access shuts the assistant out" do
    scenario "user revokes assistant access after having enabled it", context do
      given_ "assistant access has been enabled", context do
        EarWitnessSpex.SettingsSteps.set_assistant_access(context.conn, "enabled")
        context
      end

      when_ "the user revokes assistant access in settings", context do
        view = EarWitnessSpex.SettingsSteps.set_assistant_access(context.conn, "disabled")
        Map.put(context, :settings_view, view)
      end

      then_ "the assistant's tool calls are rejected, not served", context do
        assert {:error, :access_revoked} = EarWitnessWeb.McpServer.list_tools()

        assert {:error, :access_revoked} =
                 EarWitnessWeb.McpServer.search_transcripts(%{"query" => "Testing"})

        :ok
      end
    end
  end
end
