defmodule EarWitnessSpex.LetMyAiAssistantWorkMyConversations.Criterion7379Spex do
  @moduledoc """
  Story 868 — Let my AI assistant work my conversations
  Criterion 7379: Assistant saves a meeting summary onto the recording

  The one write tool the ADR (anubis-mcp) sanctions: an assistant may
  attach a summary/note to a recording, nothing else. This spec drives
  that write through the MCP surface and then reads the transcript back
  through the same surface to prove the summary actually landed on the
  recording, rather than trusting the write call's own echo.

  Judgment call made explicit here: `attach_summary/1` takes
  `%{"recording_id" => id, "summary" => text}` and returns
  `{:ok, %{recording_id: id, summary: text}}`; `read_transcript/1`'s
  result envelope carries the recording's current `:summary` alongside its
  `:segments`, so a second read is genuine round-trip evidence of
  persistence.
  """

  use EarWitnessSpex.Case

  spex "Assistant saves a meeting summary onto the recording" do
    scenario "assistant writes a summary of the meeting back onto the recording", context do
      given_ "assistant access is enabled and a recording has been transcribed", context do
        EarWitnessSpex.SettingsSteps.set_assistant_access(context.conn, "enabled")

        {show_path, _html} =
          EarWitnessSpex.RecordingSteps.import_and_transcribe(
            context.conn,
            "client-call.wav",
            EarWitnessSpex.WavFixture.short()
          )

        [_, recording_id] = Regex.run(~r{/recordings/([^/]+)}, show_path)

        context
        |> Map.put(:show_path, show_path)
        |> Map.put(:recording_id, recording_id)
      end

      when_ "the assistant attaches a meeting summary to the recording", context do
        summary = "Team agreed to ship the beta by Friday."

        attach_result =
          EarWitnessWeb.McpServer.attach_summary(%{
            "recording_id" => context.recording_id,
            "summary" => summary
          })

        context
        |> Map.put(:summary, summary)
        |> Map.put(:attach_result, attach_result)
      end

      then_ "the summary is saved onto the recording and is there when it's read back",
            context do
        assert {:ok, %{recording_id: recording_id, summary: summary}} = context.attach_result
        assert recording_id == context.recording_id
        assert summary == context.summary

        assert {:ok, %{summary: persisted_summary}} =
                 EarWitnessWeb.McpServer.read_transcript(%{
                   "recording_id" => context.recording_id
                 })

        assert persisted_summary == context.summary

        :ok
      end
    end
  end
end
