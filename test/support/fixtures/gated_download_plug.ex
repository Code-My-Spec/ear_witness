defmodule EarWitnessSpex.Fixtures.GatedDownloadPlug do
  @moduledoc """
  Test-only wrapper around `ReqCassette.Plug` that can hold model-download
  transfers in flight.

  Ungated (the default), it is a transparent pass-through to the cassette
  replay. When a test calls `hold/0`, any transfer entering this plug
  blocks until `release/0` — making "a download is genuinely still in
  progress" (story 866, criterion 7368) physically true instead of a
  timing accident, exactly like a real multi-gigabyte model file on a slow
  connection.

  Lives inside the `EarWitnessSpex.Fixtures` boundary so specs reach it
  only through the sanctioned bridge (`Fixtures.hold_model_downloads/0`).
  """

  @gate_key {__MODULE__, :gate}

  def init(opts), do: opts

  def call(conn, opts) do
    await_gate()
    ReqCassette.Plug.call(conn, ReqCassette.Plug.init(opts))
  end

  @doc "Blocks subsequent transfers until `release/0`. Idempotent."
  def hold do
    case :persistent_term.get(@gate_key, nil) do
      pid when is_pid(pid) ->
        :ok

      nil ->
        gate = spawn(fn -> Process.sleep(:infinity) end)
        :persistent_term.put(@gate_key, gate)
        :ok
    end
  end

  @doc "Releases any held transfers. Safe to call when not holding."
  def release do
    case :persistent_term.get(@gate_key, nil) do
      pid when is_pid(pid) ->
        Process.exit(pid, :kill)
        :persistent_term.erase(@gate_key)
        :ok

      nil ->
        :ok
    end
  end

  defp await_gate do
    case :persistent_term.get(@gate_key, nil) do
      nil ->
        :ok

      pid when is_pid(pid) ->
        ref = Process.monitor(pid)

        receive do
          {:DOWN, ^ref, :process, _pid, _reason} -> :ok
        end
    end
  end
end
