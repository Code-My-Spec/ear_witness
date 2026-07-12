defmodule EarWitnessSpex.LetMyAiAssistantWorkMyConversations.Criterion7378Spex do
  @moduledoc """
  Story 868 — Let my AI assistant work my conversations
  Criterion 7378: Ask the assistant what was decided

  The recording transcribes through the recorded-response engine (see
  `.code_my_spec/knowledge/bdd/spex/index.md`), so its transcript genuinely
  contains "Testing" — real whisper.cpp output from
  `test/fixtures/vad-f32.raw`. When the user asks their assistant what was
  discussed, the assistant's MCP `search_transcripts` and `read_transcript`
  calls are asserted against that real content — not an invented "decision"
  string the engine never produced.

  Judgment call made explicit here: `search_transcripts/1` takes
  `%{"query" => query}` and returns
  `{:ok, %{results: [%{recording_id: ..., text: ..., speaker: ...,
  timestamp: ...}, ...]}}`; `read_transcript/1` takes
  `%{"recording_id" => id}` and returns
  `{:ok, %{segments: [%{text: ..., speaker: ..., timestamp: ...}, ...]}}` —
  every passage carrying who said it and when, mirroring the timestamp/
  speaker guarantees already asserted through the transcript editor (story
  860 criterion 7328, story 862).
  """

  use EarWitnessSpex.Case

  spex "Ask the assistant what was decided" do
    scenario "knowledge worker asks their assistant what was said in a past conversation",
             context do
      given_ "assistant access is enabled and a recording has been transcribed", context do
        EarWitnessSpex.SettingsSteps.set_assistant_access(context.conn, "enabled")

        {show_path, _html} =
          EarWitnessSpex.RecordingSteps.import_and_transcribe(
            context.conn,
            "planning-call.wav",
            EarWitnessSpex.WavFixture.short()
          )

        [_, recording_id] = Regex.run(~r{/recordings/([^/]+)}, show_path)

        context
        |> Map.put(:show_path, show_path)
        |> Map.put(:recording_id, recording_id)
      end

      when_ "the assistant searches the library and reads the matching transcript", context do
        search_result = EarWitnessWeb.McpServer.search_transcripts(%{"query" => "Testing"})

        read_result =
          EarWitnessWeb.McpServer.read_transcript(%{"recording_id" => context.recording_id})

        context
        |> Map.put(:search_result, search_result)
        |> Map.put(:read_result, read_result)
      end

      then_ "the assistant gets back real passages, each with its speaker and timestamp",
            context do
        assert {:ok, %{results: results}} = context.search_result
        assert results != []

        assert Enum.any?(results, fn result ->
                 result.recording_id == context.recording_id and result.text =~ "Testing"
               end)

        assert Enum.all?(results, fn result ->
                 Map.has_key?(result, :speaker) and Map.has_key?(result, :timestamp)
               end)

        assert {:ok, %{segments: segments}} = context.read_result
        assert segments != []
        assert Enum.any?(segments, fn segment -> segment.text =~ "Testing" end)

        assert Enum.all?(segments, fn segment ->
                 Map.has_key?(segment, :speaker) and Map.has_key?(segment, :timestamp)
               end)

        :ok
      end
    end
  end
end
