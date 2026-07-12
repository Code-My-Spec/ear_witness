defmodule EarWitnessSpex.KeepRecordingsOrganized.Criterion7363Spex do
  @moduledoc """
  Story 865 — Keep recordings organized
  Criterion 7363: Restore a recording from the trash

  Deleting a recording is a soft delete: it moves to a trash view rather
  than disappearing outright, and can be restored back into the working
  library. This spec drives the full round trip through the real UI —
  delete, observe it in the trash with a stated retention window, restore
  it, and observe it back in the library.

  Out of scope for this spec layer: actually enforcing the 30-day
  retention (permanently purging a trashed recording once 30 days have
  elapsed). That requires real time passage, which cannot be honestly
  simulated from the sealed spec layer (no clock-manipulation seam is
  sanctioned here) — it belongs to a Tier-2 integration test against
  whatever scheduled purge job implements it. This spec only asserts (a)
  the restore path works, and (b) the trash page's *stated* retention
  copy says "30 days" — not that the purge actually happens on day 31.

  Selectors introduced: `[data-test="delete-recording-button"]` (Show —
  sends the recording to the trash), `[data-test="trash-row"]` (one per
  trashed recording, contains its title),
  `[data-test="trash-retention-notice"]` (the trash page's stated
  retention copy/badge), `[data-test="restore-button"]` (restores a
  trashed recording back to the working library). The trash page is
  assumed reachable at `/recordings/trash` — a judgment call, flagged for
  a human to confirm, consistent with keeping trash under the
  `RecordingLive` route family rather than inventing a new top-level
  surface.
  """

  use EarWitnessSpex.Case

  spex "Restore a recording from the trash" do
    scenario "hearing documenter deletes a hearing by mistake and restores it from the trash",
             context do
      given_ "a hearing recording has been imported and then sent to the trash", context do
        {show_path, _index_html} =
          EarWitnessSpex.RecordingSteps.import_wav(
            context.conn,
            "hearing-to-trash.wav",
            EarWitnessSpex.WavFixture.short()
          )

        {:ok, show_view, _html} = live(context.conn, show_path)
        show_view |> element(~s([data-test="delete-recording-button"])) |> render_click()

        Map.put(context, :show_path, show_path)
      end

      then_ "it no longer appears in the working library", context do
        {:ok, index_view, _html} = live(context.conn, "/recordings")
        refute has_element?(index_view, ~s([data-test="recording-row"]), "hearing-to-trash.wav")
        :ok
      end

      given_ "the trash page is open", context do
        {:ok, trash_view, _html} = live(context.conn, "/recordings/trash")
        Map.put(context, :trash_view, trash_view)
      end

      then_ "the trashed hearing is listed there, with a stated 30-day retention window",
            context do
        assert has_element?(
                 context.trash_view,
                 ~s([data-test="trash-row"]),
                 "hearing-to-trash.wav"
               )

        assert has_element?(
                 context.trash_view,
                 ~s([data-test="trash-retention-notice"]),
                 "30 day"
               )

        :ok
      end

      when_ "they restore the hearing from the trash", context do
        html =
          context.trash_view
          |> element(~s([data-test="trash-row"] [data-test="restore-button"]))
          |> render_click()

        Map.put(context, :trash_html, html)
      end

      then_ "it is no longer listed in the trash", context do
        refute has_element?(
                 context.trash_view,
                 ~s([data-test="trash-row"]),
                 "hearing-to-trash.wav"
               )

        :ok
      end

      then_ "it is back in the working library", context do
        {:ok, index_view, _html} = live(context.conn, "/recordings")

        assert has_element?(
                 index_view,
                 ~s([data-test="recording-row"]),
                 "hearing-to-trash.wav"
               )

        :ok
      end
    end
  end
end
