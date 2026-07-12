defmodule EarWitnessSpex.KeepRecordingsOrganized.Criterion7358Spex do
  @moduledoc """
  Story 865 — Keep recordings organized
  Criterion 7358: Create a case and add hearings to it

  Drives collection ("case/matter") creation and membership entirely
  through `RecordingLive.Index`/`.Show` — see
  `EarWitnessSpex.CollectionSteps` for the selector contract and the
  judgment calls made explicit about where this UI lives (no separate
  collection route exists per the story's sanctioned surfaces).

  This spec adds *two* existing hearings to the new case, one at a time,
  to honor the criterion's plural "hearings" — distinct from criterion
  7361 (browsing structure) and 7360 (one recording in two collections).
  """

  use EarWitnessSpex.Case

  spex "Create a case and add hearings to it" do
    scenario "hearing documenter opens a new case and adds two existing hearings to it",
             context do
      given_ "two hearing recordings already exist in the library", context do
        {show_path_1, _index_html} =
          EarWitnessSpex.RecordingSteps.import_wav(
            context.conn,
            "first-hearing.wav",
            EarWitnessSpex.WavFixture.short()
          )

        {show_path_2, _index_html} =
          EarWitnessSpex.RecordingSteps.import_wav(
            context.conn,
            "second-hearing.wav",
            EarWitnessSpex.WavFixture.short()
          )

        context
        |> Map.put(:show_path_1, show_path_1)
        |> Map.put(:show_path_2, show_path_2)
      end

      when_ "they create a new case with a name, date, and participants", context do
        {index_view, index_html} =
          EarWitnessSpex.CollectionSteps.create_collection(
            context.conn,
            "Smith v. Landlord",
            date: "2026-07-01",
            participants: "Adjudicator Smith, Jane Tenant"
          )

        context
        |> Map.put(:index_view, index_view)
        |> Map.put(:index_html, index_html)
      end

      then_ "the new case appears in the library", context do
        assert has_element?(
                 context.index_view,
                 ~s([data-test="collection"]),
                 "Smith v. Landlord"
               )

        :ok
      end

      when_ "they add the first hearing to that case", context do
        collection_id =
          EarWitnessSpex.CollectionSteps.collection_id(context.index_html, "Smith v. Landlord")

        {view, html} =
          EarWitnessSpex.CollectionSteps.add_to_collection(
            context.conn,
            context.show_path_1,
            collection_id
          )

        context
        |> Map.put(:collection_id, collection_id)
        |> Map.put(:show_view_1, view)
        |> Map.put(:show_html_1, html)
      end

      then_ "the first hearing now shows that case as one of its collections", context do
        assert has_element?(
                 context.show_view_1,
                 ~s([data-test="recording-collection"]),
                 "Smith v. Landlord"
               )

        :ok
      end

      when_ "they add the second hearing to that same case", context do
        {view, html} =
          EarWitnessSpex.CollectionSteps.add_to_collection(
            context.conn,
            context.show_path_2,
            context.collection_id
          )

        context
        |> Map.put(:show_view_2, view)
        |> Map.put(:show_html_2, html)
      end

      then_ "the second hearing now shows that case as one of its collections", context do
        assert has_element?(
                 context.show_view_2,
                 ~s([data-test="recording-collection"]),
                 "Smith v. Landlord"
               )

        :ok
      end

      then_ "browsing the library shows both hearings grouped under that case", context do
        {:ok, index_view, _html} = live(context.conn, "/recordings")

        assert has_element?(
                 index_view,
                 ~s([data-test="collection"] [data-test="recording-row"]),
                 "first-hearing.wav"
               )

        assert has_element?(
                 index_view,
                 ~s([data-test="collection"] [data-test="recording-row"]),
                 "second-hearing.wav"
               )

        :ok
      end
    end
  end
end
