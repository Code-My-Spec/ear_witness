defmodule EarWitnessSpex.FixTheTranscriptLikeOtter.Criterion7349Spex do
  @moduledoc """
  Story 863 — Fix the transcript like Otter
  Criterion 7349: Undo walks back through edits

  "Walks back through" implies more than one step of history, so this
  spec makes two edits to the same segment and undoes twice, checking the
  intermediate state after the first undo (not just the final state after
  both) — otherwise a "revert straight to original" implementation would
  pass this spec by accident.

  Judgment calls made explicit (flag for a human to confirm before
  implementation):

  - The editor route and `data-segment-id` addressing convention are
    those documented on `EarWitnessSpex.TranscriptSteps`.
  - Undo is assumed to be a single, transcript-wide control
    (`[data-test="undo-button"]`), walking back the most recent text edit
    regardless of which segment it touched — not a per-segment control.
  """

  use EarWitnessSpex.Case

  spex "Undo walks back through edits" do
    scenario "hearing documenter undoes twice after making two corrections to the same segment",
             context do
      given_ "a segment has been edited twice", context do
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

        EarWitnessSpex.TranscriptSteps.edit_segment_text(
          view,
          segment_id,
          "Testing one two three, over and out."
        )

        context
        |> Map.put(:view, view)
        |> Map.put(:segment_id, segment_id)
      end

      when_ "they undo once", context do
        EarWitnessSpex.TranscriptSteps.click_undo(context.view)
        context
      end

      then_ "the segment reverts to the first correction, not the second", context do
        assert has_element?(
                 context.view,
                 ~s([data-test="transcript-segment"][data-segment-id="#{context.segment_id}"]),
                 "Testing 1, 2, 3, over."
               )

        refute has_element?(
                 context.view,
                 ~s([data-test="transcript-segment"][data-segment-id="#{context.segment_id}"]),
                 "Testing one two three, over and out."
               )

        :ok
      end

      when_ "they undo again", context do
        EarWitnessSpex.TranscriptSteps.click_undo(context.view)
        context
      end

      then_ "the segment reverts to the original machine-heard text", context do
        assert has_element?(
                 context.view,
                 ~s([data-test="transcript-segment"][data-segment-id="#{context.segment_id}"]),
                 "Testing 1, 2, 3, testing."
               )

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
