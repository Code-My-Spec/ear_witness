defmodule EarWitness.Bots.Runner.Relay do
  @moduledoc """
  Joins a bot into the target meeting platform. Selected via the
  `config :ear_witness, :bot_relay` seam, mirroring `:transcription_engine`.

  No real Zoom/Meet/Teams integration exists yet — see the
  meeting-bot-relay ADR
  (`.code_my_spec/architecture/decisions/meeting-bot-relay.md`) — so this
  honestly reports the join as not implemented rather than pretending to
  reach a meeting platform.
  """

  @doc """
  Contract every relay implements: `:ok` once joined, `:pending` if the
  join is still in flight (the caller waits for a later signal), or
  `{:error, reason}` if the join failed outright.
  """
  @spec join(EarWitness.Bots.BotSession.t()) :: :ok | :pending | {:error, String.t()}
  def join(_session) do
    {:error,
     "Meeting bot dispatch isn't connected to a real meeting platform yet " <>
       "(see the meeting-bot-relay ADR)."}
  end
end
