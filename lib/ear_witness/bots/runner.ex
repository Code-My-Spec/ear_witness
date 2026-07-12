defmodule EarWitness.Bots.Runner do
  @moduledoc """
  Drives one bot session end to end — joins the target meeting under the
  session's display name, captures audio while the meeting is underway,
  leaves on completion or recall, and hands the captured audio off to
  `EarWitness.Recordings` as a `"bot"`-sourced recording. Reports every
  status transition back through `EarWitness.Bots`
  (`mark_recording/1`, `complete_bot_session/2`, `fail_bot_session/2`)
  rather than writing to storage itself.

  The actual meeting join runs behind the config-selected
  `EarWitness.Bots.Runner.Relay` seam (`config :ear_witness, :bot_relay`).
  There is no real meeting for a spec to join, so specs stage
  join/record/leave outcomes directly through `EarWitness.Bots` via
  `EarWitnessSpex.Fixtures.simulate_bot_*/1` instead of driving this seam.
  """

  use GenServer

  alias EarWitness.Bots
  alias EarWitness.Bots.BotSession

  @registry EarWitness.Bots.Runner.Registry
  @supervisor EarWitness.Bots.Runner.Supervisor

  @doc """
  Starts a supervised process for a freshly dispatched bot session and
  begins the join sequence against the meeting platform. Called by
  `EarWitness.Bots.dispatch_bot/1` immediately after a session is
  persisted.
  """
  @spec start_link(BotSession.t()) :: {:ok, pid()} | {:error, term()}
  def start_link(%BotSession{} = session) do
    # A session id is only ever reused if a previous run's process for that
    # id never reached a terminal status and stop (e.g. a test's sandboxed
    # insert rolled back and a later insert reused the same autoincrement
    # id) — evict it so the fresh session gets a clean registration rather
    # than colliding with a stale one.
    recall(session.id)
    DynamicSupervisor.start_child(@supervisor, {__MODULE__, session})
  end

  @doc false
  def child_spec(%BotSession{} = session) do
    %{
      id: {__MODULE__, session.id},
      start: {GenServer, :start_link, [__MODULE__, session, [name: via(session.id)]]},
      restart: :temporary
    }
  end

  @doc """
  Signals a session's running process to leave its meeting immediately
  rather than waiting for it to end on its own. Called by
  `EarWitness.Bots.recall_bot/1` after it has already marked the session
  recalled.
  """
  @spec recall(integer()) :: :ok | {:error, :not_found}
  def recall(session_id) do
    case Registry.lookup(@registry, session_id) do
      [{pid, _}] ->
        GenServer.stop(pid, :normal)
        :ok

      [] ->
        {:error, :not_found}
    end
  end

  defp via(session_id), do: {:via, Registry, {@registry, session_id}}

  @impl true
  def init(%BotSession{} = session) do
    {:ok, session, {:continue, :join}}
  end

  @impl true
  def handle_continue(:join, session) do
    case relay().join(session) do
      :ok ->
        Bots.mark_recording(session.id)
        {:noreply, session}

      :pending ->
        {:noreply, session}

      {:error, reason} ->
        Bots.fail_bot_session(session.id, reason)
        {:stop, :normal, session}
    end
  end

  defp relay do
    Application.get_env(:ear_witness, :bot_relay, EarWitness.Bots.Runner.Relay)
  end
end
