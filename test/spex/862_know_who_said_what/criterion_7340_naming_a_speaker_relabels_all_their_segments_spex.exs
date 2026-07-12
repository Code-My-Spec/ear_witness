defmodule EarWitnessSpex.KnowWhoSaidWhat.Criterion7340Spex do
  @moduledoc """
  Story 862 — Know who said what
  Criterion 7340: Naming a speaker relabels all their segments

  Drives the real `TranscriptLive.Editor` / `SpeakerPanel` naming flow and
  asserts every segment that carried the speaker's old generic label now
  carries the new name — not just that the panel chip itself was renamed.

  Judgment calls made explicit (flag for a human to confirm before
  implementation):

  - `SpeakerPanel` is assumed to render each detected speaker as
    `<... data-test="speaker-chip" data-speaker-id="...">label</...>`.
  - Renaming is assumed to go through a per-speaker form,
    `[data-test="speaker-name-form"][data-speaker-id="..."]`, submitted
    with a `"name"` field (mirroring the `form/3` pattern already used by
    `EarWitnessSpex.SettingsSteps`).
  """

  use EarWitnessSpex.Case

  spex "Naming a speaker relabels all their segments" do
    scenario "hearing documenter names a detected speaker and every one of their lines updates",
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

      given_ "the transcript editor shows an unnamed detected speaker", context do
        {view, html} = EarWitnessSpex.TranscriptSteps.open_editor(context.conn, context.show_path)

        [_, speaker_id, original_label] =
          Regex.run(
            ~r/data-test="speaker-chip" data-speaker-id="([^"]+)"[^>]*>([^<]*)</,
            html
          )

        original_label = String.trim(original_label)

        baseline_segment_count =
          ~r/data-test="segment-speaker"[^>]*>([^<]*)</
          |> Regex.scan(html)
          |> Enum.count(fn [_, text] -> String.trim(text) == original_label end)

        context
        |> Map.put(:view, view)
        |> Map.put(:speaker_id, speaker_id)
        |> Map.put(:original_label, original_label)
        |> Map.put(:baseline_segment_count, baseline_segment_count)
      end

      when_ "they name that speaker", context do
        html =
          context.view
          |> form(
            ~s([data-test="speaker-name-form"][data-speaker-id="#{context.speaker_id}"]),
            %{"name" => "Adjudicator"}
          )
          |> render_submit()

        Map.put(context, :html, html)
      end

      then_ "the speaker panel shows the new name", context do
        assert has_element?(context.view, ~s([data-test="speaker-chip"]), "Adjudicator")
        :ok
      end

      then_ "every segment previously attributed to that speaker now shows the new name, and none show the old generic label",
            context do
        new_label_count =
          ~r/data-test="segment-speaker"[^>]*>([^<]*)</
          |> Regex.scan(context.html)
          |> Enum.count(fn [_, text] -> String.trim(text) == "Adjudicator" end)

        old_label_count =
          ~r/data-test="segment-speaker"[^>]*>([^<]*)</
          |> Regex.scan(context.html)
          |> Enum.count(fn [_, text] -> String.trim(text) == context.original_label end)

        assert new_label_count == context.baseline_segment_count
        assert old_label_count == 0
        :ok
      end
    end
  end
end
