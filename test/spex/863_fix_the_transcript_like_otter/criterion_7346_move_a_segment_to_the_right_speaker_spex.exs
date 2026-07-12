defmodule EarWitnessSpex.FixTheTranscriptLikeOtter.Criterion7346Spex do
  @moduledoc """
  Story 863 — Fix the transcript like Otter
  Criterion 7346: Move a segment to the right speaker

  Reassigning one segment to a different speaker requires at least two
  distinct speakers already detected on the transcript — the honest
  precondition for that is diarization (`EarWitness.Speakers.Diarizer`,
  story 862), which does not exist yet. Rather than fake two speakers into
  existence, this given uses the same honest-raising stub story 862 uses
  for its own not-yet-buildable preconditions
  (`EarWitnessSpex.Fixtures.simulate_two_speakers_detected/0`), keeping
  this spec red at the first step. The `when_`/`then_` steps below still
  encode the full flow as it would run once diarization lands, so nothing
  has to be rewritten when it does.

  This is deliberately distinct from story 862's criterion 7340 ("Naming a
  speaker relabels all their segments"): that renames a speaker everywhere
  at once, while this criterion moves a single segment without touching
  any other segment's attribution.

  Judgment calls made explicit (flag for a human to confirm before
  implementation):

  - The editor route, `data-segment-id` addressing, and
    `[data-test="speaker-chip"][data-speaker-id="..."]` panel markup are
    those already established by `EarWitnessSpex.TranscriptSteps` and
    story 862's specs.
  - The per-segment reassignment control is assumed to be a form,
    `[data-test="segment-speaker-form"][data-segment-id="..."]`, submitted
    with a `"speaker_id"` field.
  - `[data-test="segment-speaker"]` elements are assumed to also carry the
    owning segment's `data-segment-id`, so a single segment's displayed
    speaker can be asserted without disturbing the other segment's.
  - Before reassignment, the untouched segment ("Testing 1, 2, 3,
    testing.") is assumed to already be attributed to whichever speaker
    chip diarization lists first — the scenario asserts that same label
    is still shown on it afterward, whatever it turns out to be. The
    moved segment ("1, 2, 3.") is reassigned to the *other* chip.
  """

  use EarWitnessSpex.Case

  spex "Move a segment to the right speaker" do
    scenario "hearing documenter reassigns a single segment to the speaker who actually said it",
             context do
      given_ "a transcribed recording has two distinct detected speakers", context do
        EarWitnessSpex.Fixtures.simulate_two_speakers_detected()

        {show_path, _transcribed_html} =
          EarWitnessSpex.RecordingSteps.import_and_transcribe(
            context.conn,
            "two-person-hearing.wav",
            EarWitnessSpex.WavFixture.short()
          )

        Map.put(context, :show_path, show_path)
      end

      when_ "they reassign one segment to the other detected speaker", context do
        {view, html} = EarWitnessSpex.TranscriptSteps.open_editor(context.conn, context.show_path)

        speakers =
          ~r/data-test="speaker-chip" data-speaker-id="([^"]+)"[^>]*>([^<]*)</
          |> Regex.scan(html)
          |> Enum.map(fn [_, id, label] -> {id, String.trim(label)} end)

        [{_untouched_speaker_id, untouched_speaker_label}, {target_speaker_id, target_speaker_label}] =
          speakers

        moved_segment_id = EarWitnessSpex.TranscriptSteps.segment_id(html, "1, 2, 3.")
        untouched_segment_id = EarWitnessSpex.TranscriptSteps.segment_id(html, "Testing 1, 2, 3, testing.")

        changed_html =
          EarWitnessSpex.TranscriptSteps.reassign_segment_speaker(
            view,
            moved_segment_id,
            target_speaker_id
          )

        context
        |> Map.put(:view, view)
        |> Map.put(:changed_html, changed_html)
        |> Map.put(:moved_segment_id, moved_segment_id)
        |> Map.put(:untouched_segment_id, untouched_segment_id)
        |> Map.put(:target_speaker_label, target_speaker_label)
        |> Map.put(:untouched_speaker_label, untouched_speaker_label)
      end

      then_ "the reassigned segment now shows the other speaker", context do
        assert has_element?(
                 context.view,
                 ~s([data-test="segment-speaker"][data-segment-id="#{context.moved_segment_id}"]),
                 context.target_speaker_label
               )

        :ok
      end

      then_ "the other segment keeps its original speaker attribution", context do
        assert has_element?(
                 context.view,
                 ~s([data-test="segment-speaker"][data-segment-id="#{context.untouched_segment_id}"]),
                 context.untouched_speaker_label
               )

        :ok
      end
    end
  end
end
