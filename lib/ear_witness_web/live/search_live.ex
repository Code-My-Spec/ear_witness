defmodule EarWitnessWeb.SearchLive do
  @moduledoc """
  Search the whole conversation library by phrase, speaker, or date;
  results jump into the transcript editor at the matching segment.
  """

  use EarWitnessWeb, :live_view

  alias EarWitness.Search
  alias EarWitnessWeb.RecordingLive.Format

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <h1 class="text-2xl font-bold">Search</h1>

      <form id="search-form" data-test="search-form" phx-change="search" class="space-y-3">
        <label class="input input-bordered flex w-full items-center gap-2">
          <.icon name="hero-magnifying-glass" class="size-4 opacity-60" />
          <input
            type="text"
            name="q"
            value={@query}
            placeholder="Search everything ever said..."
            phx-debounce="200"
            class="grow"
          />
        </label>

        <div data-test="search-filters" class="flex flex-wrap gap-2">
          <input
            type="text"
            name="speaker"
            value={@filters["speaker"]}
            placeholder="Speaker"
            phx-debounce="200"
            class="input input-bordered input-sm"
          />
          <input type="date" name="from" value={@filters["from"]} class="input input-bordered input-sm" />
          <input type="date" name="to" value={@filters["to"]} class="input input-bordered input-sm" />
        </div>
      </form>

      <p :if={@query != "" and @results == []} class="text-sm opacity-70">
        Nothing matches yet.
      </p>

      <div class="space-y-3">
        <.result :for={hit <- @results} hit={hit} />
      </div>
    </div>
    """
  end

  defp result(%{hit: %{type: :segment}} = assigns) do
    ~H"""
    <div data-test="search-result" class="card bg-base-100 border border-base-300 shadow-sm">
      <.link
        navigate={~p"/recordings/#{@hit.recording_id}/transcript?#{[segment: @hit.segment_id]}"}
        class="card-body gap-1 py-3 hover:bg-base-200"
      >
        <div class="flex flex-wrap items-center gap-2 text-sm opacity-70">
          <.icon name="hero-document-text" class="size-4" />
          <span data-test="result-recording-title" class="font-medium text-base-content">
            {@hit.recording_title}
          </span>
          <span data-test="result-timestamp" class="tnum badge badge-ghost badge-sm">
            {Format.duration(@hit.timestamp / 1000)}
          </span>
          <span data-test="result-speaker" class="badge badge-outline badge-sm">{@hit.speaker}</span>
        </div>
        <p data-test="result-snippet" class="text-base-content">{@hit.snippet}</p>
      </.link>
    </div>
    """
  end

  defp result(%{hit: %{type: :recording}} = assigns) do
    ~H"""
    <div data-test="recording-result" class="card bg-base-100 border border-base-300 shadow-sm">
      <.link navigate={~p"/recordings/#{@hit.recording_id}"} class="card-body gap-1 py-3 hover:bg-base-200">
        <span data-test="result-recording-title" class="flex items-center gap-2 font-medium">
          <.icon name="hero-folder" class="size-4" /> {@hit.recording_title}
        </span>
        <p data-test="result-snippet" class="text-base-content">{@hit.snippet}</p>
      </.link>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       query: "",
       filters: %{"speaker" => "", "from" => "", "to" => ""},
       results: []
     )}
  end

  @impl true
  def handle_event("search", params, socket) do
    # Query and filters live in one form, so every change carries the full
    # state. Missing keys fall back to the current assign rather than being
    # blanked — a change to one field never wipes another (issue 110f3c94,
    # where a filter interaction raced the query and reset it to empty).
    current = socket.assigns

    query = Map.get(params, "q", current.query)

    filters = %{
      "speaker" => Map.get(params, "speaker", current.filters["speaker"]),
      "from" => Map.get(params, "from", current.filters["from"]),
      "to" => Map.get(params, "to", current.filters["to"])
    }

    {:noreply, socket |> assign(query: query, filters: filters) |> run_search()}
  end

  defp run_search(socket) do
    assign(socket, :results, results_for(socket.assigns.query, socket.assigns.filters))
  end

  defp results_for("", _filters), do: []

  defp results_for(query, filters) do
    Search.search(query, search_opts(filters))
  end

  defp search_opts(filters) do
    [
      speaker: blank(filters["speaker"]),
      from: parse_date(filters["from"]),
      to: parse_date(filters["to"])
    ]
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp blank(""), do: nil
  defp blank(value), do: value

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil

  defp parse_date(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      {:error, _} -> nil
    end
  end
end
