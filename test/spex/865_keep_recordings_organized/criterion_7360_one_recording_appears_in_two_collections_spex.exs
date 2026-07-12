defmodule EarWitnessSpex.KeepRecordingsOrganized.Criterion7360Spex do
  @moduledoc """
  Story 865 — Keep recordings organized
  Criterion 7360: One recording appears in two collections

  Collections are tag-style / multi-membership, per the story's example
  map: "a hearing can live in its case AND the weekly review". This spec
  puts a single hearing into two distinct cases at once and asserts it
  renders under both when browsing — and that it is still one recording,
  not silently duplicated (`data-recording-id` matches across both
  renders; new selector, see below).

  Selector introduced: `[data-test="recording-row"]` is assumed to also
  carry `data-recording-id="..."` (the same id for the same underlying
  recording rendered in more than one collection group) — needed to
  distinguish "one recording shown twice" from "two recordings".
  """

  use EarWitnessSpex.Case

  spex "One recording appears in two collections" do
    scenario "hearing documenter puts one hearing into both its case and the weekly review",
             context do
      given_ "a hearing recording exists in the library", context do
        {show_path, _index_html} =
          EarWitnessSpex.RecordingSteps.import_wav(
            context.conn,
            "shared-hearing.wav",
            EarWitnessSpex.WavFixture.short()
          )

        Map.put(context, :show_path, show_path)
      end

      given_ "two separate collections already exist", context do
        {_view, case_html} =
          EarWitnessSpex.CollectionSteps.create_collection(context.conn, "123 Main St Case")

        {_view, review_html} =
          EarWitnessSpex.CollectionSteps.create_collection(context.conn, "Weekly Review")

        case_id = EarWitnessSpex.CollectionSteps.collection_id(case_html, "123 Main St Case")
        review_id = EarWitnessSpex.CollectionSteps.collection_id(review_html, "Weekly Review")

        context
        |> Map.put(:case_id, case_id)
        |> Map.put(:review_id, review_id)
      end

      when_ "they add the hearing to both collections at once", context do
        {view, html} =
          EarWitnessSpex.CollectionSteps.set_collections(
            context.conn,
            context.show_path,
            [context.case_id, context.review_id]
          )

        context
        |> Map.put(:show_view, view)
        |> Map.put(:show_html, html)
      end

      then_ "the hearing shows both collections as its own", context do
        assert has_element?(
                 context.show_view,
                 ~s([data-test="recording-collection"]),
                 "123 Main St Case"
               )

        assert has_element?(
                 context.show_view,
                 ~s([data-test="recording-collection"]),
                 "Weekly Review"
               )

        :ok
      end

      then_ "browsing the library shows the hearing listed under each collection separately",
            context do
        {:ok, index_view, _html} = live(context.conn, "/recordings")

        assert has_element?(
                 index_view,
                 ~s([data-test="collection"][data-collection-id="#{context.case_id}"] [data-test="recording-row"]),
                 "shared-hearing.wav"
               )

        assert has_element?(
                 index_view,
                 ~s([data-test="collection"][data-collection-id="#{context.review_id}"] [data-test="recording-row"]),
                 "shared-hearing.wav"
               )

        :ok
      end

      then_ "it is still one single recording, not duplicated into two", context do
        {:ok, index_view, _html} = live(context.conn, "/recordings")
        html = render(index_view)

        rows = Regex.scan(~r/data-test="recording-row"/, html)

        ids =
          ~r/data-test="recording-row" data-recording-id="([^"]+)"/
          |> Regex.scan(html)
          |> Enum.map(fn [_, id] -> id end)
          |> Enum.uniq()

        # rendered once per collection group it belongs to...
        assert length(rows) == 2
        # ...but every rendering refers to the same underlying recording.
        assert length(ids) == 1
        :ok
      end
    end
  end
end
