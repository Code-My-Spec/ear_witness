defmodule EarWitness.Bots do
  @moduledoc """
  Meeting bots for meetings the user can't attend — dispatch a bot that
  joins a call as a visible participant, records it, and deposits the
  audio into the recordings library for the normal
  transcription/diarization pipeline.
  """

  import Ecto.Query

  alias EarWitness.Bots.{BotSession, Runner}
  alias EarWitness.Repo

  @topic "bot_sessions"

  @doc """
  Creates a new bot session for a pasted meeting link and starts a
  `Runner` to join, record, and report back. The session is immediately
  visible with status `:dispatched`; joining happens asynchronously.
  """
  @spec dispatch_bot(map()) :: {:ok, BotSession.t()} | {:error, Ecto.Changeset.t()}
  def dispatch_bot(attrs) do
    %BotSession{}
    |> BotSession.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, session} ->
        {:ok, _pid} = Runner.start_link(session)
        broadcast(session)
        {:ok, session}

      error ->
        error
    end
  end

  @doc "Returns every dispatched bot session, most recent first."
  @spec list_bot_sessions() :: [BotSession.t()]
  def list_bot_sessions do
    BotSession
    |> order_by([s], desc: s.inserted_at, desc: s.id)
    |> Repo.all()
  end

  @doc "Pulls a bot back out of its meeting before it would finish on its own."
  @spec recall_bot(integer() | String.t()) ::
          {:ok, BotSession.t()} | {:error, :not_found | :not_recallable}
  def recall_bot(id) do
    with {:ok, session} <- fetch_session(id),
         :ok <- ensure_recallable(session) do
      update_status(session, %{status: :recalled})
    end
  end

  @doc "Marks a session as actively recording once the bot successfully joins the meeting."
  @spec mark_recording(integer() | String.t()) :: {:ok, BotSession.t()} | {:error, :not_found}
  def mark_recording(id) do
    with {:ok, session} <- fetch_session(id) do
      update_status(session, %{status: :recording})
    end
  end

  @doc """
  Called by the `Runner` once it has left the meeting and handed the
  captured audio to `EarWitness.Recordings`. Links the session to the
  resulting recording so it appears in the library.
  """
  @spec complete_bot_session(integer() | String.t(), integer()) ::
          {:ok, BotSession.t()} | {:error, :not_found}
  def complete_bot_session(id, recording_id) do
    with {:ok, session} <- fetch_session(id) do
      update_status(session, %{status: :completed, recording_id: recording_id})
    end
  end

  @doc """
  Records that a bot session's join attempt failed, with a human-readable
  reason so the failure is reported rather than swallowed.
  """
  @spec fail_bot_session(integer() | String.t(), String.t()) ::
          {:ok, BotSession.t()} | {:error, :not_found}
  def fail_bot_session(id, reason) do
    with {:ok, session} <- fetch_session(id) do
      update_status(session, %{status: :failed, failure_reason: reason})
    end
  end

  @doc """
  Subscribes the calling process to bot session status updates, so the
  monitor UI reflects dispatch, recording, completion, recall, and
  failure without polling.
  """
  @spec subscribe() :: :ok | {:error, term()}
  def subscribe do
    Phoenix.PubSub.subscribe(EarWitness.PubSub, @topic)
  end

  defp ensure_recallable(%BotSession{status: status})
       when status in [:completed, :recalled, :failed],
       do: {:error, :not_recallable}

  defp ensure_recallable(%BotSession{}), do: :ok

  defp update_status(session, attrs) do
    if terminal?(attrs[:status]), do: Runner.recall(session.id)

    session
    |> Ecto.Changeset.change(attrs)
    |> Repo.update()
    |> case do
      {:ok, session} ->
        broadcast(session)
        {:ok, session}

      error ->
        error
    end
  end

  defp terminal?(status), do: status in [:completed, :recalled, :failed]

  defp fetch_session(id) do
    case Repo.get(BotSession, id) do
      nil -> {:error, :not_found}
      session -> {:ok, session}
    end
  end

  defp broadcast(session) do
    Phoenix.PubSub.broadcast(EarWitness.PubSub, @topic, {:bot_session_updated, session})
  end
end
