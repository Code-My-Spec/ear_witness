defmodule EarWitnessSpex.SearchSteps do
  @moduledoc """
  Reusable steps for driving `EarWitnessWeb.SearchLive` from BDD specs.

  Selector contract (extends the BDD plan's conventions):

  - `[data-test="search-form"]` — the search box form, field name `"q"`
  - `[data-test="search-result"]` — one per transcript hit, carrying
    `[data-test="result-snippet"]`, `[data-test="result-recording-title"]`,
    `[data-test="result-timestamp"]`, `[data-test="result-speaker"]`
  - `[data-test="recording-result"]` — a title/collection/speaker-name hit
    (as opposed to a transcript-text hit)
  - `[data-test="search-speaker-filter"]` / `[data-test="search-date-filter"]`
    — filter form controls (fields `"speaker"`, `"from"`, `"to"`)
  """

  @endpoint EarWitnessWeb.Endpoint

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @doc "Opens search and submits a query. Returns `{view, results_html}`."
  def search(conn, query) do
    {:ok, view, _html} = live(conn, "/search")

    html =
      view
      |> form(~s([data-test="search-form"]), %{"q" => query})
      |> render_change()

    {view, html}
  end
end
