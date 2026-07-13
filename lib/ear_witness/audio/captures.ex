defmodule EarWitness.Audio.Captures do
  @moduledoc """
  In-memory registry of running captures, keyed by the `ref`
  `EarWitness.Audio.Pipeline.capture/2` hands back, so
  `EarWitness.Audio.Pipeline.stop/1` can find what was started.
  """

  use Agent

  def start_link(_opts), do: Agent.start_link(fn -> %{} end, name: __MODULE__)

  def put(ref, capture), do: Agent.update(__MODULE__, &Map.put(&1, ref, capture))

  def get(ref), do: Agent.get(__MODULE__, &Map.get(&1, ref))

  def pop(ref), do: Agent.get_and_update(__MODULE__, &Map.pop(&1, ref))
end
