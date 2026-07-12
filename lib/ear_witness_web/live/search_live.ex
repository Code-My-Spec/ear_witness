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
    <div class="p-6 space-y-6">
      <form id="search-form" data-test="search-form" phx-change="search">
        <input
          type="text"
          name="q"
          value={@query}
          placeholder="Search everything ever said..."
          class="input input-bordered w-full"
        />
      </form>

      <form id="search-filters" data-test="search-filters" phx-change="filter" class="flex flex-wrap gap-2">
        <input
          type="text"
          name="speaker"
          value={@filters["speaker"]}
          placeholder="Speaker"
          class="input input-bordered input-sm"
        />
        <input type="date" name="from" value={@filters["from"]} class="input input-bordered input-sm" />
        <input type="date" name="to" value={@filters["to"]} class="input input-bordered input-sm" />
      </form>

      <div class="space-y-3">
        <.result :for={hit <- @results} hit={hit} />
      </div>
    </div>
    """
  end

  defp result(%{hit: %{type: :segment}} = assigns) do
    ~H"""
    <div data-test="search-result" class="card card-body bg-base-100 shadow-sm">
      <.link
        navigate={~p"/recordings/#{@hit.recording_id}/transcript?#{[segment: @hit.segment_id]}"}
        class="block space-y-1"
      >
        <div class="flex flex-wrap items-center gap-2 text-sm opacity-70">
          <span data-test="result-recording-title">{@hit.recording_title}</span>
          <span data-test="result-timestamp">{Format.duration(@hit.timestamp / 1000)}</span>
          <span data-test="result-speaker">{@hit.speaker}</span>
        </div>
        <p data-test="result-snippet">{@hit.snippet}</p>
      </.link>
    </div>
    """
  end

  defp result(%{hit: %{type: :recording}} = assigns) do
    ~H"""
    <div data-test="recording-result" class="card card-body bg-base-100 shadow-sm">
      <.link navigate={~p"/recordings/#{@hit.recording_id}"} class="block space-y-1">
        <span data-test="result-recording-title">{@hit.recording_title}</span>
        <p data-test="result-snippet">{@hit.snippet}</p>
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
  def handle_event("search", %{"q" => query}, socket) do
    {:noreply, socket |> assign(:query, query) |> run_search()}
  end

  def handle_event("filter", params, socket) do
    filters = %{
      "speaker" => Map.get(params, "speaker", ""),
      "from" => Map.get(params, "from", ""),
      "to" => Map.get(params, "to", "")
    }

    {:noreply, socket |> assign(:filters, filters) |> run_search()}
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
