defmodule EarWitnessSpex.FindAnythingEverSaid.Criterion7354Spex do
  @moduledoc """
  Story 864 — Find anything ever said
  Criterion 7354: Results are readable without opening them
  """

  use EarWitnessSpex.Case

  spex "Results are readable without opening them" do
    scenario "knowledge worker scans the result list without opening anything", context do
      given_ "a transcribed recording matches a search", context do
        EarWitnessSpex.RecordingSteps.import_and_transcribe(
          context.conn,
          "hearing.wav",
          EarWitnessSpex.WavFixture.short()
        )

        {view, html} = EarWitnessSpex.SearchSteps.search(context.conn, "Testing")

        context
        |> Map.put(:view, view)
        |> Map.put(:html, html)
      end

      when_ "they read the result list", context do
        context
      end

      then_ "each hit shows a snippet of surrounding text, the recording title, and the timestamp",
            context do
        result_count = length(Regex.scan(~r/data-test="search-result"/, context.html))
        snippet_count = length(Regex.scan(~r/data-test="result-snippet"/, context.html))
        title_count = length(Regex.scan(~r/data-test="result-recording-title"/, context.html))
        stamp_count = length(Regex.scan(~r/data-test="result-timestamp"/, context.html))

        assert result_count > 0
        assert snippet_count == result_count
        assert title_count == result_count
        assert stamp_count == result_count
        :ok
      end

      then_ "the snippet carries the matched phrase in context", context do
        assert has_element?(context.view, ~s([data-test="result-snippet"]), "Testing")
        :ok
      end
    end
  end
end
