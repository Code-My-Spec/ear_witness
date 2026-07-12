defmodule EarWitnessSpex.KnowWhoSaidWhat.Criterion7343Spex do
  @moduledoc """
  Story 862 — Know who said what
  Criterion 7343: Overlapping or unclear speech is marked unknown, not misattributed

  Diarization runs behind the `Speakers.Diarizer` seam; the recorded
  cassette it replays must itself contain a genuine ambiguous/overlapping
  passage (captured from real audio, per the project's "doubles replay
  recorded real output" rule) for this spec to exercise the behavior — the
  spec cannot manufacture ambiguity from the in-memory WAV fixture bytes
  themselves. This spec asserts the required *observable*: at least one
  segment is labeled `"Unknown"` rather than confidently attributed to one
  of the panel's identified speakers.

  Judgment call made explicit: the literal label for an unresolved segment
  is assumed to be the text `"Unknown"` on `[data-test="segment-speaker"]`
  — flag for a human to confirm the exact copy before implementation.
  """

  use EarWitnessSpex.Case

  spex "Overlapping or unclear speech is marked unknown, not misattributed" do
    scenario "hearing documenter reads a transcript with a cross-talk passage", context do
      given_ "a recording containing overlapping or unclear speech has been imported and transcribed",
             context do
        {show_path, _transcribed_html} =
          EarWitnessSpex.RecordingSteps.import_and_transcribe(
            context.conn,
            "cross-talk-hearing.wav",
            EarWitnessSpex.WavFixture.short()
          )

        Map.put(context, :show_path, show_path)
      end

      when_ "they open the transcript editor", context do
        {view, html} = EarWitnessSpex.TranscriptSteps.open_editor(context.conn, context.show_path)

        context
        |> Map.put(:view, view)
        |> Map.put(:html, html)
      end

      then_ "the unclear passage is marked unknown rather than attributed to either identified speaker",
            context do
        panel_labels =
          ~r/data-test="speaker-chip"[^>]*>([^<]*)</
          |> Regex.scan(context.html)
          |> Enum.map(fn [_, label] -> String.trim(label) end)

        assert has_element?(context.view, ~s([data-test="segment-speaker"]), "Unknown")
        refute "Unknown" in panel_labels
        :ok
      end
    end
  end
end
