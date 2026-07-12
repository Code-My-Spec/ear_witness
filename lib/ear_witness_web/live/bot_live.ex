defmodule EarWitnessWeb.BotLive do
  @moduledoc """
  Meeting-bot dispatch and session tracking (story 869 — "Send a bot to
  the meetings I can't attend"). Paste a meeting link, optionally rename
  the bot from its default identity, dispatch it, and watch its status
  move through dispatched -> recording -> completed/recalled/failed, with
  a recall action while it's still underway.
  """

  use EarWitnessWeb, :live_view

  alias EarWitness.Bots
  alias EarWitness.Bots.BotSession

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Bots.subscribe()

    {:ok,
     assign(socket,
       bot_sessions: Bots.list_bot_sessions(),
       default_display_name: %BotSession{}.display_name
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <h1 class="text-2xl font-bold">Meeting Bots</h1>

      <div class="card bg-base-100 border border-base-300 shadow-sm">
        <div class="card-body">
          <h2 class="card-title">
            <.icon name="hero-user-plus" class="size-5 text-primary" /> Dispatch a bot
          </h2>
          <form
            id="bot-dispatch-form"
            data-test="bot-dispatch-form"
            phx-submit="dispatch_bot"
            class="flex flex-col gap-3"
          >
            <label class="form-control">
              <span class="label-text">Meeting link</span>
              <input
                type="text"
                name="bot[meeting_url]"
                placeholder="https://zoom.us/j/..."
                class="input input-bordered"
                required
              />
            </label>
            <label class="form-control">
              <span class="label-text">Bot name</span>
              <input
                type="text"
                name="bot[display_name]"
                value={@default_display_name}
                class="input input-bordered"
              />
            </label>
            <button type="submit" class="btn btn-primary self-start">
              <.icon name="hero-paper-airplane" class="size-4" /> Send bot
            </button>
          </form>
        </div>
      </div>

      <div class="card bg-base-100 border border-base-300 shadow-sm">
        <div class="card-body">
          <h2 class="card-title">Sessions</h2>
          <p :if={@bot_sessions == []} class="text-sm opacity-70">
            No bots dispatched yet.
          </p>
          <%!--
            Story 869 `_spex.exs` scans resolve a session's id from
            `data-test="bot-session" data-session-id="..."` immediately
            adjacent (no attribute may land between them).
          --%>
          <div
            :for={session <- @bot_sessions}
            data-test="bot-session"
            data-session-id={session.id}
            class="flex flex-wrap items-center gap-4 border-b border-base-200 py-2 last:border-b-0"
          >
            <span class="font-mono text-sm opacity-70">{session.meeting_url}</span>
            <span data-test="bot-display-name" data-session-id={session.id} class="font-medium">
              {session.display_name}
            </span>
            <span data-test="bot-status" data-session-id={session.id} class={["badge", status_badge(session.status)]}>
              {session.status}
            </span>
            <span
              :if={session.status == :failed}
              data-test="bot-failure-reason"
              data-session-id={session.id}
              class="text-sm text-error"
            >
              {session.failure_reason}
            </span>
            <button
              :if={session.status in [:dispatched, :recording]}
              type="button"
              data-test="recall-button"
              data-session-id={session.id}
              phx-click="recall_bot"
              phx-value-session_id={session.id}
              class="btn btn-sm btn-outline"
            >
              <.icon name="hero-phone-x-mark" class="size-4" /> Recall
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp status_badge(:dispatched), do: "badge-info"
  defp status_badge(:recording), do: "badge-error"
  defp status_badge(:completed), do: "badge-success"
  defp status_badge(:recalled), do: "badge-ghost"
  defp status_badge(:failed), do: "badge-error"

  @impl true
  def handle_event("dispatch_bot", %{"bot" => params}, socket) do
    case Bots.dispatch_bot(params) do
      {:ok, _session} ->
        {:noreply, assign(socket, :bot_sessions, Bots.list_bot_sessions())}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end

  def handle_event("recall_bot", %{"session_id" => id}, socket) do
    case Bots.recall_bot(id) do
      {:ok, _session} -> {:noreply, assign(socket, :bot_sessions, Bots.list_bot_sessions())}
      {:error, _reason} -> {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:bot_session_updated, _session}, socket) do
    {:noreply, assign(socket, :bot_sessions, Bots.list_bot_sessions())}
  end
end
