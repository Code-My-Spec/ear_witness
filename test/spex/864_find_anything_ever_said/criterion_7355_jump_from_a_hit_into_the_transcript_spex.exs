defmodule EarWitnessSpex.FindAnythingEverSaid.Criterion7355Spex do
  @moduledoc """
  Story 864 — Find anything ever said
  Criterion 7355: Jump from a hit into the transcript

  Clicking a hit navigates to the transcript editor scrolled to the
  matching segment — asserted as a LiveView navigation whose destination
  marks the target segment `[data-test="focused-segment"]` containing the
  searched phrase.
  """

  use EarWitnessSpex.Case

  spex "Jump from a hit into the transcript" do
    scenario "knowledge worker opens a search hit at the exact passage", context do
      given_ "a search produced a hit in a hearing's transcript", context do
        EarWitnessSpex.RecordingSteps.import_and_transcribe(
          context.conn,
          "hearing.wav",
          EarWitnessSpex.WavFixture.short()
        )

        {view, _html} = EarWitnessSpex.SearchSteps.search(context.conn, "Testing")
        Map.put(context, :view, view)
      end

      when_ "they open the first result", context do
        {:ok, editor_view, editor_html} =
          context.view
          |> element(~s([data-test="search-result"] a), "Testing")
          |> render_click()
          |> follow_redirect(context.conn)

        context
        |> Map.put(:editor_view, editor_view)
        |> Map.put(:editor_html, editor_html)
      end

      then_ "the transcript editor opens scrolled to the matching segment", context do
        assert has_element?(context.editor_view, ~s([data-test="transcript"]))

        assert has_element?(
                 context.editor_view,
                 ~s([data-test="focused-segment"]),
                 "Testing"
               )

        :ok
      end
    end
  end
end
