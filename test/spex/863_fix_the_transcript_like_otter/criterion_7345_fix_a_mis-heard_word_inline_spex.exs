defmodule EarWitnessSpex.FixTheTranscriptLikeOtter.Criterion7345Spex do
  @moduledoc """
  Story 863 — Fix the transcript like Otter
  Criterion 7345: Fix a mis-heard word inline

  Edits the real segment text the recorded-response double replays
  (`test/fixtures/transcription_cassettes/vad-f32.json`, captured from
  actual whisper.cpp output — "Testing 1, 2, 3, testing.") rather than a
  placeholder string, per the project's "doubles replay recorded real
  output" rule.

  Judgment calls made explicit (flag for a human to confirm before
  implementation):

  - The editor route and `data-segment-id` addressing convention are
    those documented on `EarWitnessSpex.TranscriptSteps`.
  - The inline text editor is assumed to be a per-segment form,
    `[data-test="segment-editor"][data-segment-id="..."]`, submitted with
    a `"text"` field (mirroring the `speaker-name-form` pattern already
    used by story 862's specs).
  """

  use EarWitnessSpex.Case

  spex "Fix a mis-heard word inline" do
    scenario "hearing documenter corrects a mis-heard word in a transcript segment", context do
      given_ "a recording has been imported and transcribed", context do
        {show_path, _transcribed_html} =
          EarWitnessSpex.RecordingSteps.import_and_transcribe(
            context.conn,
            "hearing.wav",
            EarWitnessSpex.WavFixture.short()
          )

        Map.put(context, :show_path, show_path)
      end

      when_ "they edit a segment's text inline", context do
        {view, html} = EarWitnessSpex.TranscriptSteps.open_editor(context.conn, context.show_path)

        segment_id = EarWitnessSpex.TranscriptSteps.segment_id(html, "Testing 1, 2, 3, testing.")

        changed_html =
          EarWitnessSpex.TranscriptSteps.edit_segment_text(
            view,
            segment_id,
            "Testing 1, 2, 3, over."
          )

        context
        |> Map.put(:view, view)
        |> Map.put(:segment_id, segment_id)
        |> Map.put(:changed_html, changed_html)
      end

      then_ "the transcript shows the corrected text", context do
        assert has_element?(
                 context.view,
                 ~s([data-test="transcript-segment"][data-segment-id="#{context.segment_id}"]),
                 "Testing 1, 2, 3, over."
               )

        :ok
      end

      then_ "the mis-heard original text is no longer shown for that segment", context do
        refute has_element?(
                 context.view,
                 ~s([data-test="transcript-segment"][data-segment-id="#{context.segment_id}"]),
                 "Testing 1, 2, 3, testing."
               )

        :ok
      end
    end
  end
end
