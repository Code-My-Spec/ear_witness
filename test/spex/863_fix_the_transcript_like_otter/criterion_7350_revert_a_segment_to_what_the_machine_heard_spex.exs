defmodule EarWitnessSpex.FixTheTranscriptLikeOtter.Criterion7350Spex do
  @moduledoc """
  Story 863 — Fix the transcript like Otter
  Criterion 7350: Revert a segment to what the machine heard

  Asserts restoration of the transcription engine's actual recorded
  output ("Testing 1, 2, 3, testing." — from
  `test/fixtures/transcription_cassettes/vad-f32.json`, captured from real
  whisper.cpp inference), not a placeholder string, per the project's
  "doubles replay recorded real output" rule. This is distinct from undo
  (criterion 7349): revert restores one segment's original machine
  transcription directly, regardless of how many edits it has
  accumulated, rather than stepping back through edit history one step
  at a time.

  Judgment calls made explicit (flag for a human to confirm before
  implementation):

  - The editor route and `data-segment-id` addressing convention are
    those documented on `EarWitnessSpex.TranscriptSteps`.
  - The revert control is assumed to be a per-segment button,
    `[data-test="revert-button"][data-segment-id="..."]`.
  """

  use EarWitnessSpex.Case

  spex "Revert a segment to what the machine heard" do
    scenario "hearing documenter reverts a corrected segment back to the machine transcription",
             context do
      given_ "a segment's text has been corrected away from what the machine heard", context do
        {show_path, _transcribed_html} =
          EarWitnessSpex.RecordingSteps.import_and_transcribe(
            context.conn,
            "hearing.wav",
            EarWitnessSpex.WavFixture.short()
          )

        {view, html} = EarWitnessSpex.TranscriptSteps.open_editor(context.conn, show_path)
        segment_id = EarWitnessSpex.TranscriptSteps.segment_id(html, "Testing 1, 2, 3, testing.")

        EarWitnessSpex.TranscriptSteps.edit_segment_text(
          view,
          segment_id,
          "Testing 1, 2, 3, over."
        )

        context
        |> Map.put(:view, view)
        |> Map.put(:segment_id, segment_id)
      end

      when_ "they revert that segment", context do
        EarWitnessSpex.TranscriptSteps.click_revert(context.view, context.segment_id)
        context
      end

      then_ "the segment shows exactly what the transcription engine originally produced",
            context do
        assert has_element?(
                 context.view,
                 ~s([data-test="transcript-segment"][data-segment-id="#{context.segment_id}"]),
                 "Testing 1, 2, 3, testing."
               )

        :ok
      end

      then_ "the corrected text is no longer shown", context do
        refute has_element?(
                 context.view,
                 ~s([data-test="transcript-segment"][data-segment-id="#{context.segment_id}"]),
                 "Testing 1, 2, 3, over."
               )

        :ok
      end
    end
  end
end
