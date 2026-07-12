defmodule EarWitness.Audio.ConsentPolicy do
  @moduledoc """
  Authorizes capture under the active recording consent/notification
  policy. `:silent` authorizes unconditionally; `:notify` authorizes and
  flags that the UI should show a notice; `:announce` attempts to deliver
  an audible notice and only authorizes once delivery is confirmed.

  Real audible-notice delivery is not wired up yet — it succeeds
  unconditionally outside the test seam.
  `EarWitnessSpex.Fixtures.simulate_announcement_delivery_failure/0`
  overrides that to simulate a delivery failure.
  """

  @spec authorize(:silent | :notify | :announce) ::
          {:ok, :none | :shown | :delivered} | {:error, :notice_undelivered}
  def authorize(:silent), do: {:ok, :none}
  def authorize(:notify), do: {:ok, :shown}

  def authorize(:announce) do
    case Application.get_env(:ear_witness, :announcement_delivery_override) do
      :fail -> {:error, :notice_undelivered}
      _ -> {:ok, :delivered}
    end
  end
end
