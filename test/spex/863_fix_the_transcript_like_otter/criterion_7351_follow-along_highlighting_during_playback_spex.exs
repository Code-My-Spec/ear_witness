defmodule EarWitnessSpex.FixTheTranscriptLikeOtter.Criterion7351Spex do
  @moduledoc """
  Story 863 — Fix the transcript like Otter
  Criterion 7351: Follow-along highlighting during playback

  Whether audio actually plays through the machine's speakers, and the
  real-time `<audio>` timeupdate events that would move the highlight on
  their own, are a browser/webview concern outside what
  `Phoenix.LiveViewTest` can observe (same caveat as criterion 7347). This
  spec asserts the UI contract the highlight must satisfy as playback
  moves from one passage to the next: clicking a second passage while a
  first is already marked playing moves the `[data-test="playing-segment"]`
  marker onto the new passage and off the old one — the highlight follows
  along rather than sticking or accumulating. It is distinct from
  criterion 7347, which only covers the initial click on a single passage;
  this one is about the marker relocating as the "current" passage
  changes.

  Judgment calls made explicit (flag for a human to confirm before
  implementation):

  - The editor route and `data-segment-id` addressing convention are
    those documented on `EarWitnessSpex.TranscriptSteps`.
  - Clicking a second segment's container while an earlier one is playing
    is treated as a stand-in for the playhead reaching that segment
    during real playback — both should move the "currently playing"
    state the same way.
  """

  use EarWitnessSpex.Case

  spex "Follow-along highlighting during playback" do
    scenario "hearing documenter watches the highlight follow along as playback reaches the next passage",
             context do
      given_ "a recording has been imported and transcribed, and its first passage is playing",
             context do
        {show_path, _transcribed_html} =
          EarWitnessSpex.RecordingSteps.import_and_transcribe(
            context.conn,
            "hearing.wav",
            EarWitnessSpex.WavFixture.short()
          )

        {view, html} = EarWitnessSpex.TranscriptSteps.open_editor(context.conn, show_path)

        first_segment_id = EarWitnessSpex.TranscriptSteps.segment_id(html, "Testing 1, 2, 3, testing.")
        second_segment_id = EarWitnessSpex.TranscriptSteps.segment_id(html, "1, 2, 3.")

        EarWitnessSpex.TranscriptSteps.click_segment(view, first_segment_id)

        context
        |> Map.put(:view, view)
        |> Map.put(:first_segment_id, first_segment_id)
        |> Map.put(:second_segment_id, second_segment_id)
      end

      when_ "playback reaches the next passage", context do
        EarWitnessSpex.TranscriptSteps.click_segment(context.view, context.second_segment_id)
        context
      end

      then_ "the highlight has moved onto the new passage", context do
        assert has_element?(
                 context.view,
                 ~s([data-test="transcript-segment"][data-segment-id="#{context.second_segment_id}"] [data-test="playing-segment"])
               )

        :ok
      end

      then_ "the previous passage is no longer highlighted", context do
        refute has_element?(
                 context.view,
                 ~s([data-test="transcript-segment"][data-segment-id="#{context.first_segment_id}"] [data-test="playing-segment"])
               )

        :ok
      end
    end
  end
end
