defmodule EarWitnessTest.PendingBotRelay do
  @moduledoc """
  Test double for the `EarWitness.Bots.Runner` join seam
  (`config :ear_witness, :bot_relay`).

  There is no real meeting for a spec to join, so this always reports the
  join as still pending — a freshly dispatched session simply stays
  `:dispatched` until a spec stages an outcome directly through
  `EarWitness.Bots` (`EarWitnessSpex.Fixtures.simulate_bot_join_completed/1`
  and friends), the same honest-seam pattern as
  `EarWitnessTest.RecordedTranscriptionEngine`.
  """

  @spec join(EarWitness.Bots.BotSession.t()) :: :pending
  def join(_session), do: :pending
end
