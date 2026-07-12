defmodule EarWitnessSpex.FixTheTranscriptLikeOtter.Criterion7348Spex do
  @moduledoc """
  Story 863 — Fix the transcript like Otter
  Criterion 7348: Edits are still there after a restart

  There is no way to kill the whole BEAM node mid-test and relaunch it
  (see story 860's criterion 7330, which establishes this pattern for
  `RecordingLive.Show`), so "the app restarts" is encoded the way it is
  observable from the user's side: a fresh `conn` plus a fresh `live/2`
  mount of the same editor path stands in for closing and reopening the
  app.

  Judgment calls made explicit (flag for a human to confirm before
  implementation):

  - The editor route and `data-segment-id` addressing convention are
    those documented on `EarWitnessSpex.TranscriptSteps`.
  - `data-segment-id` values are assumed stable across a fresh mount of
    the same recording (they identify a persisted segment row, not
    view-local state).
  """

  use EarWitnessSpex.Case

  spex "Edits are still there after a restart" do
    scenario "hearing documenter reopens the transcript editor after editing and closing the app",
             context do
      given_ "a segment's text has been corrected in the editor", context do
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
        |> Map.put(:show_path, show_path)
        |> Map.put(:segment_id, segment_id)
      end

      when_ "the app is relaunched and the same transcript is reopened", context do
        fresh_conn = Phoenix.ConnTest.build_conn()

        {reopened_view, reopened_html} =
          EarWitnessSpex.TranscriptSteps.open_editor(fresh_conn, context.show_path)

        context
        |> Map.put(:reopened_view, reopened_view)
        |> Map.put(:reopened_html, reopened_html)
      end

      then_ "the corrected text is still shown", context do
        assert has_element?(
                 context.reopened_view,
                 ~s([data-test="transcript-segment"][data-segment-id="#{context.segment_id}"]),
                 "Testing 1, 2, 3, over."
               )

        :ok
      end

      then_ "the pre-edit machine-heard text is not shown", context do
        refute has_element?(
                 context.reopened_view,
                 ~s([data-test="transcript-segment"][data-segment-id="#{context.segment_id}"]),
                 "Testing 1, 2, 3, testing."
               )

        :ok
      end
    end
  end
end
