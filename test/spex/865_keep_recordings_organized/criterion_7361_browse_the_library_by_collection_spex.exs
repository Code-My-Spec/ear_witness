defmodule EarWitnessSpex.KeepRecordingsOrganized.Criterion7361Spex do
  @moduledoc """
  Story 865 — Keep recordings organized
  Criterion 7361: Browse the library by collection

  Asserts the library index groups recordings under their collection
  ("case") and keeps recordings that belong to no collection visible in
  a separate, clearly distinct section
  (`[data-test="uncategorized-recordings"]`) rather than dropping them —
  a growing library without drowning in a flat file list only works if
  recordings without a case are still reachable.
  """

  use EarWitnessSpex.Case

  spex "Browse the library by collection" do
    scenario "hearing documenter opens the library and sees recordings grouped by case",
             context do
      given_ "one case exists containing one hearing, and a second hearing has no case",
             context do
        {show_path_a, _index_html} =
          EarWitnessSpex.RecordingSteps.import_wav(
            context.conn,
            "categorized-hearing.wav",
            EarWitnessSpex.WavFixture.short()
          )

        {_show_path_b, _index_html} =
          EarWitnessSpex.RecordingSteps.import_wav(
            context.conn,
            "uncategorized-hearing.wav",
            EarWitnessSpex.WavFixture.short()
          )

        EarWitnessSpex.CollectionSteps.add_tag(context.conn, show_path_a, "Case A")

        context
      end

      when_ "they open the recordings library", context do
        {:ok, view, html} = live(context.conn, "/recordings")

        context
        |> Map.put(:view, view)
        |> Map.put(:html, html)
      end

      then_ "the categorized hearing appears grouped under its case", context do
        assert has_element?(context.view, ~s([data-test="collection"]), "Case A")

        assert has_element?(
                 context.view,
                 ~s([data-test="collection"] [data-test="recording-row"]),
                 "categorized-hearing.wav"
               )

        :ok
      end

      then_ "the uncategorized hearing appears in its own section, not under any case", context do
        assert has_element?(
                 context.view,
                 ~s([data-test="uncategorized-recordings"] [data-test="recording-row"]),
                 "uncategorized-hearing.wav"
               )

        refute has_element?(
                 context.view,
                 ~s([data-test="collection"] [data-test="recording-row"]),
                 "uncategorized-hearing.wav"
               )

        :ok
      end
    end
  end
end
