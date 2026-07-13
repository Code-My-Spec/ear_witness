defmodule EarWitnessSpex.KeepRecordingsOrganized.Criterion7362Spex do
  @moduledoc """
  Story 865 — Keep recordings organized
  Criterion 7362: Removing a case keeps its recordings

  Deleting a collection is a safe, structural-only operation — it must
  never cascade to the recordings that were members of it. This spec
  deletes a case through the real library UI and asserts both that the
  case itself is gone and that its hearing is still fully present and
  reachable (still listed, and its own show page still opens) — not just
  that a row happens to remain, since a soft-cascade could still leave a
  broken reference behind.

  Selector introduced: `[data-test="delete-collection-button"]`,
  scoped by `data-collection-id="..."` on `RecordingLive.Index` — mirrors
  the `data-collection-id` scoping already used by
  `EarWitnessSpex.CollectionSteps` and criterion 7360.
  """

  use EarWitnessSpex.Case

  spex "Removing a case keeps its recordings" do
    scenario "hearing documenter deletes a case and its hearing remains in the library",
             context do
      given_ "a case exists containing one hearing", context do
        {show_path, _index_html} =
          EarWitnessSpex.RecordingSteps.import_wav(
            context.conn,
            "hearing-in-a-case.wav",
            EarWitnessSpex.WavFixture.short()
          )

        {_view, collection_html} =
          EarWitnessSpex.CollectionSteps.create_collection(context.conn, "Case To Delete")

        collection_id =
          EarWitnessSpex.CollectionSteps.collection_id(collection_html, "Case To Delete")

        EarWitnessSpex.CollectionSteps.add_tag(context.conn, show_path, "Case To Delete")

        context
        |> Map.put(:show_path, show_path)
        |> Map.put(:collection_id, collection_id)
      end

      when_ "they delete the case", context do
        {:ok, index_view, _html} = live(context.conn, "/recordings")

        html =
          index_view
          |> element(
            ~s([data-test="delete-collection-button"][data-collection-id="#{context.collection_id}"])
          )
          |> render_click()

        context
        |> Map.put(:index_view, index_view)
        |> Map.put(:html, html)
      end

      then_ "the case itself is gone from the library", context do
        refute has_element?(context.index_view, ~s([data-test="collection"]), "Case To Delete")
        :ok
      end

      then_ "the hearing that was in it is still listed in the library", context do
        assert has_element?(
                 context.index_view,
                 ~s([data-test="recording-row"]),
                 "hearing-in-a-case.wav"
               )

        :ok
      end

      then_ "the hearing itself still opens normally", context do
        {:ok, show_view, _html} = live(context.conn, context.show_path)

        assert has_element?(
                 show_view,
                 ~s([data-test="recording-title"]),
                 "hearing-in-a-case.wav"
               )

        :ok
      end
    end
  end
end
