defmodule EarWitnessSpex.KnowWhoSaidWhat.Criterion7339Spex do
  @moduledoc """
  Story 862 — Know who said what
  Criterion 7339: Two-person hearing shows two distinct speakers

  Diarization runs behind the `Speakers.Diarizer` seam (VAD + speaker-
  embedding ONNX models via ortex, clustered) automatically once
  transcription completes — no separate "diarize" action exists in the UI
  (see `.code_my_spec/architecture/decisions/speaker-diarization.md`). This
  spec drives the real transcribe flow through `RecordingLive.Show` and
  then reads the result off `TranscriptLive.Editor`'s `SpeakerPanel` and
  segment list.

  Judgment calls made explicit (flag for a human to confirm before
  implementation):

  - The editor route is assumed to be `<recording show_path>/transcript`
    — see `EarWitnessSpex.TranscriptSteps` moduledoc.
  - `SpeakerPanel` is assumed to render one `[data-test="speaker-chip"]`
    per detected speaker, whose text is that speaker's current display
    label (a generic label like "Speaker 1" before naming).
  - Each transcript segment is assumed to carry a
    `[data-test="segment-speaker"]` element whose text matches one of the
    panel's current speaker labels.
  """

  use EarWitnessSpex.Case

  spex "Two-person hearing shows two distinct speakers" do
    scenario "hearing documenter transcribes a two-person hearing and reads the speaker panel",
             context do
      given_ "a recording of a two-person hearing has been imported and transcribed", context do
        {show_path, _transcribed_html} =
          EarWitnessSpex.RecordingSteps.import_and_transcribe(
            context.conn,
            "two-person-hearing.wav",
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

      then_ "the speaker panel shows exactly two distinct speakers, and every segment is attributed to one of them",
            context do
        panel_labels =
          ~r/data-test="speaker-chip"[^>]*>([^<]*)</
          |> Regex.scan(context.html)
          |> Enum.map(fn [_, label] -> String.trim(label) end)

        segment_labels =
          ~r/data-test="segment-speaker"[^>]*>([^<]*)</
          |> Regex.scan(context.html)
          |> Enum.map(fn [_, label] -> String.trim(label) end)

        assert length(Enum.uniq(panel_labels)) == 2
        assert segment_labels != []
        assert Enum.all?(segment_labels, &(&1 in panel_labels))
        :ok
      end
    end
  end
end
