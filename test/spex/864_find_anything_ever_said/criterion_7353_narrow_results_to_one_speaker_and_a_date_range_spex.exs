defmodule EarWitnessSpex.FindAnythingEverSaid.Criterion7353Spex do
  @moduledoc """
  Story 864 — Find anything ever said
  Criterion 7353: Narrow results to one speaker and a date range

  Speaker attribution on transcripts comes from the diarization seam
  (story 862); this spec filters on whatever speaker the seam attributes,
  read off the filter's own options, rather than hardcoding a name it
  cannot honestly stage. Date filtering uses the recordings' true dates
  (created in this test run — today), so an including range must keep the
  results and an empty-past range must clear them.
  """

  use EarWitnessSpex.Case

  spex "Narrow results to one speaker and a date range" do
    scenario "knowledge worker narrows search hits by speaker and date", context do
      given_ "search results spanning transcribed recordings exist", context do
        EarWitnessSpex.RecordingSteps.import_and_transcribe(
          context.conn,
          "hearing.wav",
          EarWitnessSpex.WavFixture.short()
        )

        {view, html} = EarWitnessSpex.SearchSteps.search(context.conn, "Testing")

        [_, speaker] =
          Regex.run(~r/data-test="result-speaker"[^>]*>([^<]*)</, html) ||
            raise "no result-speaker rendered — diarization seam missing?"

        context
        |> Map.put(:view, view)
        |> Map.put(:speaker, String.trim(speaker))
      end

      when_ "they filter to one speaker within a date range that includes the recordings",
            context do
        html =
          context.view
          |> form(~s([data-test="search-form"]), %{
            "speaker" => context.speaker,
            "from" => Date.to_iso8601(Date.add(Date.utc_today(), -30)),
            "to" => Date.to_iso8601(Date.utc_today())
          })
          |> render_change()

        Map.put(context, :filtered_html, html)
      end

      then_ "only that speaker's matches from that period remain", context do
        speakers =
          ~r/data-test="result-speaker"[^>]*>([^<]*)</
          |> Regex.scan(context.filtered_html)
          |> Enum.map(fn [_, s] -> String.trim(s) end)

        assert speakers != []
        assert Enum.all?(speakers, &(&1 == context.speaker))
        :ok
      end

      then_ "an all-in-the-past date range clears the results", context do
        html =
          context.view
          |> form(~s([data-test="search-form"]), %{
            "speaker" => context.speaker,
            "from" => "2020-01-01",
            "to" => "2020-12-31"
          })
          |> render_change()

        refute html =~ ~s(data-test="search-result")
        :ok
      end
    end
  end
end
