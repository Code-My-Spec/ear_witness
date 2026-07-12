defmodule EarWitnessSpex.CollectionSteps do
  @moduledoc """
  Reusable steps for driving collection ("case/matter") creation and
  membership from BDD specs, through `EarWitnessWeb.RecordingLive.Index`
  and `.Show` — story 865 ("Keep recordings organized").

  Plain helper functions, not macros — the installed `sexy_spex` version
  (`~> 0.1.0`) has no shared-given registration mechanism, so specs call
  these directly from inside `given_`/`when_`/`then_` blocks (same
  rationale as `EarWitnessSpex.RecordingSteps` and
  `EarWitnessSpex.TranscriptSteps`). Every call here stays on the real
  LiveView surface — nothing here reaches into `EarWitness.*` contexts,
  `Repo`, `File`, or `Port` (see the local Credo check `EARWIT0001`).

  ## Judgment calls made explicit (flag for a human before implementation)

  - Collection creation happens inline on the library index
    (`[data-test="collection-form"]`, fields `collection[name]`,
    `collection[date]`, `collection[participants]`) rather than on a
    separate route, since only `RecordingLive.Index`/`.Show` are the
    sanctioned surfaces for story 865 (see the project BDD plan).
  - `participants` is a single free-text field (e.g. a comma-separated
    list of names), not a repeating field group.
  - Collections are tag-style / multi-membership (a hearing can live in
    its case AND, say, a weekly review) — per the Three Amigos example
    map for story 865 — so membership is a checkbox group, not a
    single-select.
  - Per-recording collection membership is toggled on
    `RecordingLive.Show` via `[data-test="recording-collections-form"]`,
    field `recording[collection_ids][]`. Each available collection is
    rendered as `[data-test="collection-option"] [data-collection-id="..."]`
    wrapping the collection's plain name text — so specs can resolve a
    collection's id from its rendered name without touching the DB
    (mirrors `EarWitnessSpex.TranscriptSteps.segment_id/2`).
  - Read-only confirmation that a recording currently belongs to a
    collection is assumed to render as
    `[data-test="recording-collection"]` chips on `RecordingLive.Show`
    (distinct from the editable checkbox form), and as
    `[data-test="collection"][data-collection-id="..."]` group headings
    wrapping that collection's `[data-test="recording-row"]` entries on
    `RecordingLive.Index`.
  """

  @endpoint EarWitnessWeb.Endpoint

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @doc """
  Opens the library and creates a collection ("case") with the given
  `name` through the real collection form. Accepts `:date` and
  `:participants` options. Returns `{index_view, html}` — the index
  LiveView and its rendered HTML right after creation.
  """
  def create_collection(conn, name, opts \\ []) do
    {:ok, view, _html} = live(conn, "/recordings")

    html =
      view
      |> form(~s([data-test="collection-form"]), %{
        "collection" => %{
          "name" => name,
          "date" => Keyword.get(opts, :date, Date.to_iso8601(Date.utc_today())),
          "participants" => Keyword.get(opts, :participants, "")
        }
      })
      |> render_submit()

    {view, html}
  end

  @doc """
  Finds the `data-collection-id` of the collection whose rendered name
  matches `name`, by scanning `html` for any element carrying a
  `data-collection-id` attribute (`[data-test="collection-option"]` on
  the membership form, `[data-test="collection"]` on the index group
  heading). Mirrors `EarWitnessSpex.TranscriptSteps.segment_id/2`.
  """
  def collection_id(html, name) do
    ~r/data-collection-id="([^"]+)"[^>]*>\s*([^<]*)</
    |> Regex.scan(html)
    |> Enum.find(fn [_, _id, option_name] -> String.contains?(option_name, name) end)
    |> then(fn [_, id, _name] -> id end)
  end

  @doc """
  Opens the recording at `show_path` and sets its full collection
  membership to exactly `collection_ids` through the real membership
  checkbox form (`[data-test="recording-collections-form"]`). Returns
  `{view, html}` after the change.
  """
  def set_collections(conn, show_path, collection_ids) do
    {:ok, view, _html} = live(conn, show_path)

    html =
      view
      |> form(~s([data-test="recording-collections-form"]), %{
        "recording" => %{"collection_ids" => collection_ids}
      })
      |> render_change()

    {view, html}
  end

  @doc """
  Adds the recording at `show_path` to the single collection identified
  by `collection_id`, through `set_collections/3`. Returns `{view, html}`
  after the change.
  """
  def add_to_collection(conn, show_path, collection_id),
    do: set_collections(conn, show_path, [collection_id])
end
