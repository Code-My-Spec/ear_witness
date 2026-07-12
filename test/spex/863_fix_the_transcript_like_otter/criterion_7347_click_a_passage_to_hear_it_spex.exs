defmodule EarWitnessSpex.FixTheTranscriptLikeOtter.Criterion7347Spex do
  @moduledoc """
  Story 863 — Fix the transcript like Otter
  Criterion 7347: Click a passage to hear it

  Whether audio actually plays through the machine's speakers is a
  browser/webview concern outside what `Phoenix.LiveViewTest` can observe.
  This spec instead asserts the UI contract a click-to-play control must
  satisfy: clicking a segment marks it, and only it, as the one currently
  playing — via a `[data-test="playing-segment"]` marker nested inside
  that segment's container. Whether the `<audio>` element actually seeks
  and plays is left to the (future) browser-driven QA pass, not this spec.

  Judgment calls made explicit (flag for a human to confirm before
  implementation):

  - The editor route and `data-segment-id` addressing convention are
    those documented on `EarWitnessSpex.TranscriptSteps`.
  - Clicking anywhere on a segment's container
    (`[data-test="transcript-segment"][data-segment-id="..."]`) is
    assumed to start playback there.
  - The currently-playing segment is assumed to render a nested
    `[data-test="playing-segment"]` marker that no other segment carries.
  """

  use EarWitnessSpex.Case

  spex "Click a passage to hear it" do
    scenario "hearing documenter clicks a transcript passage to hear the audio behind it",
             context do
      given_ "a recording has been imported and transcribed", context do
        {show_path, _transcribed_html} =
          EarWitnessSpex.RecordingSteps.import_and_transcribe(
            context.conn,
            "hearing.wav",
            EarWitnessSpex.WavFixture.short()
          )

        Map.put(context, :show_path, show_path)
      end

      when_ "they click a transcript passage", context do
        {view, html} = EarWitnessSpex.TranscriptSteps.open_editor(context.conn, context.show_path)

        clicked_segment_id = EarWitnessSpex.TranscriptSteps.segment_id(html, "Testing 1, 2, 3, testing.")
        other_segment_id = EarWitnessSpex.TranscriptSteps.segment_id(html, "1, 2, 3.")

        EarWitnessSpex.TranscriptSteps.click_segment(view, clicked_segment_id)

        context
        |> Map.put(:view, view)
        |> Map.put(:clicked_segment_id, clicked_segment_id)
        |> Map.put(:other_segment_id, other_segment_id)
      end

      then_ "the clicked passage is marked as the one currently playing", context do
        assert has_element?(
                 context.view,
                 ~s([data-test="transcript-segment"][data-segment-id="#{context.clicked_segment_id}"] [data-test="playing-segment"])
               )

        :ok
      end

      then_ "no other passage is marked as playing", context do
        refute has_element?(
                 context.view,
                 ~s([data-test="transcript-segment"][data-segment-id="#{context.other_segment_id}"] [data-test="playing-segment"])
               )

        :ok
      end
    end
  end
end
