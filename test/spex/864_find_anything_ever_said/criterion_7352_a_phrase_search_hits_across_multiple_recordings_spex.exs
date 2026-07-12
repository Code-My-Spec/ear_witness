defmodule EarWitnessSpex.FindAnythingEverSaid.Criterion7352Spex do
  @moduledoc """
  Story 864 — Find anything ever said
  Criterion 7352: A phrase search hits across multiple recordings

  Both recordings transcribe through the recorded-response engine, so both
  transcripts genuinely contain the phrase "Testing" (real whisper.cpp
  output from test/fixtures/vad-f32.raw) — the search hits assert against
  words the engine really produced.
  """

  use EarWitnessSpex.Case

  spex "A phrase search hits across multiple recordings" do
    scenario "knowledge worker searches a phrase said in several hearings", context do
      given_ "several transcribed recordings mention the same phrase", context do
        for name <- ["first-hearing.wav", "second-hearing.wav"] do
          EarWitnessSpex.RecordingSteps.import_and_transcribe(
            context.conn,
            name,
            EarWitnessSpex.WavFixture.short()
          )
        end

        context
      end

      when_ "they search for the phrase", context do
        {view, html} = EarWitnessSpex.SearchSteps.search(context.conn, "Testing")

        context
        |> Map.put(:view, view)
        |> Map.put(:html, html)
      end

      then_ "results include matching passages from each of those recordings", context do
        results = Regex.scan(~r/data-test="search-result"/, context.html)
        assert length(results) >= 2

        assert has_element?(
                 context.view,
                 ~s([data-test="result-recording-title"]),
                 "first-hearing.wav"
               )

        assert has_element?(
                 context.view,
                 ~s([data-test="result-recording-title"]),
                 "second-hearing.wav"
               )

        :ok
      end
    end
  end
end
