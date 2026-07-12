defmodule EarWitnessSpex.FindAnythingEverSaid.Criterion7357Spex do
  @moduledoc """
  Story 864 — Find anything ever said
  Criterion 7357: Find a recording by its title

  Search covers titles/collections/speaker names as well as transcript
  text (PM decision, Three Amigos 2026-07-11). A title hit renders as
  `[data-test="recording-result"]`, distinct from transcript-text hits.
  """

  use EarWitnessSpex.Case

  spex "Find a recording by its title" do
    scenario "knowledge worker finds a hearing by part of its title", context do
      given_ "a recording titled 'LTB hearing — 123 Main St' exists", context do
        EarWitnessSpex.RecordingSteps.import_wav(
          context.conn,
          "LTB hearing — 123 Main St.wav",
          EarWitnessSpex.WavFixture.short()
        )

        context
      end

      when_ "they search for part of the title", context do
        {view, html} = EarWitnessSpex.SearchSteps.search(context.conn, "123 Main")

        context
        |> Map.put(:view, view)
        |> Map.put(:html, html)
      end

      then_ "the recording itself appears in the results", context do
        assert has_element?(
                 context.view,
                 ~s([data-test="recording-result"]),
                 "123 Main"
               )

        :ok
      end
    end
  end
end
