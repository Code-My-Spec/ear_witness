defmodule EarWitnessSpex.FindAnythingEverSaid.Criterion7356Spex do
  @moduledoc """
  Story 864 — Find anything ever said
  Criterion 7356: Corrected words become findable

  Reuses story 863's inline-edit flow (`EarWitnessSpex.TranscriptSteps`)
  to correct a word the recorded engine really produced, then asserts
  search finds the correction — proving the index follows edits, not just
  the original machine text.
  """

  use EarWitnessSpex.Case

  spex "Corrected words become findable" do
    scenario "knowledge worker corrects a mis-heard word and then finds it by search", context do
      given_ "a transcribed recording whose segment text was corrected to 'abatement'",
             context do
        {show_path, _html} =
          EarWitnessSpex.RecordingSteps.import_and_transcribe(
            context.conn,
            "hearing.wav",
            EarWitnessSpex.WavFixture.short()
          )

        {view, html} = EarWitnessSpex.TranscriptSteps.open_editor(context.conn, show_path)
        segment_id = EarWitnessSpex.TranscriptSteps.segment_id(html, "Testing")

        EarWitnessSpex.TranscriptSteps.edit_segment_text(
          view,
          segment_id,
          "abatement hearing continues"
        )

        context
      end

      when_ "they search for the corrected word", context do
        {view, html} = EarWitnessSpex.SearchSteps.search(context.conn, "abatement")

        context
        |> Map.put(:view, view)
        |> Map.put(:html, html)
      end

      then_ "the corrected segment appears in the results", context do
        assert has_element?(context.view, ~s([data-test="result-snippet"]), "abatement")
        :ok
      end

      then_ "the replaced original wording no longer matches", context do
        {_view, html} = EarWitnessSpex.SearchSteps.search(context.conn, "Testing")
        refute html =~ ~s(data-test="search-result")
        :ok
      end
    end
  end
end
