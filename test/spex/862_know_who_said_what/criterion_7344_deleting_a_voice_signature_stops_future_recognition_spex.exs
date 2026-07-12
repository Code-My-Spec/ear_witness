defmodule EarWitnessSpex.KnowWhoSaidWhat.Criterion7344Spex do
  @moduledoc """
  Story 862 — Know who said what
  Criterion 7344: Deleting a voice signature stops future recognition

  Like criterion 7341, the precondition — "a named speaker with a stored
  voice signature already exists from a prior recording" — cannot be
  staged honestly yet, so this spec uses the same honest-raising stub,
  `EarWitnessSpex.Fixtures.simulate_known_speaker_with_voice_signature/1`.
  That keeps the spec red at the first step; the `when_`/`then_` steps
  below encode the full flow as it would actually run once the
  `Speakers.Diarizer`/`Speakers.Identifier` seam lands: delete the voice
  signature through the real `SpeakerPanel`, then transcribe a fresh
  recording of the same voice and assert it is no longer auto-attributed
  to the deleted speaker's name.

  Judgment calls made explicit (flag for a human to confirm before
  implementation):

  - `SpeakerPanel` is assumed to be where a known speaker's voice
    signature is managed (named, merged, recolored — and, per this
    criterion, deleted/forgotten), since the story defines no separate
    speaker-management surface.
  - The delete action is assumed to be a clickable element,
    `[data-test="delete-voice-signature"][data-speaker-name="..."]`,
    scoped by the speaker's current display name.
  """

  use EarWitnessSpex.Case

  spex "Deleting a voice signature stops future recognition" do
    scenario "hearing documenter deletes a known speaker's voice signature and the next recording no longer matches it",
             context do
      given_ "a named speaker with a stored voice signature already exists from a prior recording",
             context do
        EarWitnessSpex.Fixtures.simulate_known_speaker_with_voice_signature("Alex")

        {show_path, _transcribed_html} =
          EarWitnessSpex.RecordingSteps.import_and_transcribe(
            context.conn,
            "first-meeting-with-alex.wav",
            EarWitnessSpex.WavFixture.short()
          )

        Map.put(context, :show_path, show_path)
      end

      when_ "they delete that speaker's voice signature from the speaker panel", context do
        {view, _html} =
          EarWitnessSpex.TranscriptSteps.open_editor(context.conn, context.show_path)

        html =
          view
          |> element(~s([data-test="delete-voice-signature"][data-speaker-name="Alex"]))
          |> render_click()

        context
        |> Map.put(:view, view)
        |> Map.put(:html, html)
      end

      when_ "a new recording featuring the same voice is imported and transcribed", context do
        {show_path, _transcribed_html} =
          EarWitnessSpex.RecordingSteps.import_and_transcribe(
            context.conn,
            "third-meeting-with-alex.wav",
            EarWitnessSpex.WavFixture.short()
          )

        {view, html} = EarWitnessSpex.TranscriptSteps.open_editor(context.conn, show_path)

        context
        |> Map.put(:view, view)
        |> Map.put(:html, html)
      end

      then_ "the new transcript's segments are not attributed to the deleted speaker's name", context do
        refute has_element?(context.view, ~s([data-test="segment-speaker"]), "Alex")
        :ok
      end
    end
  end
end
