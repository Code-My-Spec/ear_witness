defmodule EarWitnessSpex.KeepRecordingsOrganized.Criterion7359Spex do
  @moduledoc """
  Story 865 — Keep recordings organized
  Criterion 7359: Edit a recording's metadata

  "Metadata" per the story text is title, date, and participants —
  edited together through one form on `RecordingLive.Show`
  (`[data-test="recording-metadata-form"]`, fields `recording[title]`,
  `recording[date]`, `recording[participants]`) rather than three
  separate controls, since the story frames them as one editable unit
  ("titles, dates, and participants"). Flag for a human to confirm
  before implementation whether the real UI actually combines them into
  a single form.

  Display selectors introduced: `[data-test="recording-title"]`,
  `[data-test="recording-date"]`, `[data-test="recording-participants"]`
  on `RecordingLive.Show` — read-only render of the current metadata.
  """

  use EarWitnessSpex.Case

  spex "Edit a recording's metadata" do
    scenario "hearing documenter corrects a recording's title, date, and participants",
             context do
      given_ "a recording exists in the library with its original, generic title", context do
        {show_path, _index_html} =
          EarWitnessSpex.RecordingSteps.import_wav(
            context.conn,
            "hearing-jul-1.wav",
            EarWitnessSpex.WavFixture.short()
          )

        Map.put(context, :show_path, show_path)
      end

      when_ "they edit its title, date, and participants", context do
        {:ok, view, _html} = live(context.conn, context.show_path)

        html =
          view
          |> form(~s([data-test="recording-metadata-form"]), %{
            "recording" => %{
              "title" => "LTB Hearing — 123 Main St",
              "date" => "2026-07-01",
              "participants" => "Adjudicator Smith, Jane Tenant"
            }
          })
          |> render_submit()

        context
        |> Map.put(:view, view)
        |> Map.put(:html, html)
      end

      then_ "the recording shows the new title, date, and participants", context do
        assert has_element?(
                 context.view,
                 ~s([data-test="recording-title"]),
                 "LTB Hearing — 123 Main St"
               )

        assert has_element?(context.view, ~s([data-test="recording-date"]), "2026-07-01")

        assert has_element?(
                 context.view,
                 ~s([data-test="recording-participants"]),
                 "Adjudicator Smith"
               )

        :ok
      end

      then_ "the new title is what appears when browsing the library", context do
        {:ok, index_view, _html} = live(context.conn, "/recordings")

        assert has_element?(
                 index_view,
                 ~s([data-test="recording-row"]),
                 "LTB Hearing — 123 Main St"
               )

        refute has_element?(index_view, ~s([data-test="recording-row"]), "hearing-jul-1.wav")
        :ok
      end

      then_ "the edited metadata is still there after reloading the recording", context do
        {:ok, reloaded_view, _html} = live(context.conn, context.show_path)

        assert has_element?(
                 reloaded_view,
                 ~s([data-test="recording-title"]),
                 "LTB Hearing — 123 Main St"
               )

        :ok
      end
    end
  end
end
