defmodule EarWitnessSpex.Fixtures.FakeCaptureReader do
  @moduledoc """
  Controllable stand-in for `EarWitness.Audio.Miniaudio.read_new/1` — the drain
  side of the live-transcription spec seam (story 872).

  `EarWitness.Transcription.LiveTranscriber` drains its capture through the
  module named by `config :ear_witness, :capture_reader` (default the real NIF).
  `config/test.exs` points that at this module, so under the `:fixture_live`
  capture (see `EarWitnessSpex.Fixtures.enable_live_capture_seam/0`) the
  transcriber pulls whatever a spec has pushed here instead of real device
  audio. A single shared queue backs it — specs run synchronously, one capture
  at a time — so the capture handle is ignored.

  Lives under the `EarWitnessSpex.Fixtures` boundary (not `EarWitnessTest`) so
  the fixture helpers can drive it without a cross-boundary reference; the
  production transcriber only ever reaches it through the runtime config atom.
  """

  @name __MODULE__

  @doc "Starts (if needed) and empties the shared queue — call once per scenario."
  @spec reset() :: :ok
  def reset do
    ensure_started()
    Agent.update(@name, fn _ -> <<>> end)
  end

  @doc "Enqueues PCM16 bytes for the transcriber to drain on its next read."
  @spec push(binary()) :: :ok
  def push(pcm) when is_binary(pcm) do
    ensure_started()
    Agent.update(@name, fn buffered -> buffered <> pcm end)
  end

  @doc """
  The `read_new/1` reader contract: hands back everything pushed since the last
  read (16kHz mono PCM16 bytes) and clears the queue. The handle is ignored.
  """
  @spec read_new(term()) :: {:ok, binary()}
  def read_new(_handle) do
    ensure_started()
    {:ok, Agent.get_and_update(@name, fn buffered -> {buffered, <<>>} end)}
  end

  # Unlinked + named so the queue survives across the spec's process boundaries
  # (the transcriber reads it from its own process) and persists for the run;
  # `reset/0` clears it between scenarios.
  defp ensure_started do
    case Agent.start(fn -> <<>> end, name: @name) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end
  end
end
