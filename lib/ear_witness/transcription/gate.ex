defmodule EarWitness.Transcription.Gate do
  @moduledoc """
  Serializes every real whisper.cpp NIF invocation app-wide. The engine has
  three independent callers — the Oban batch `Worker`, the `LiveTranscriber`,
  and the legacy `Transcription.Server` — and each whisper run loads a full
  model, so letting them overlap can exhaust the machine. All of them resolve
  to `EarWitness.Transcription.Engine`, which funnels the NIF call through
  `run/1` here: one transcription at a time, callers queued FIFO in this
  process's mailbox.

  A crash inside the gated function is returned to its caller as
  `{:error, reason}` (the engine's normal failure shape) rather than crashing
  the gate, so one bad file can't take down every queued transcription.
  """

  use GenServer

  @busy_table __MODULE__.Busy

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @doc """
  Runs `fun` once no other transcription is in flight. Blocks the caller
  until its turn comes and the work finishes — transcription can take
  minutes, hence the infinite timeout.
  """
  @spec run((-> {:ok, term()} | {:error, term()})) :: {:ok, term()} | {:error, term()}
  def run(fun) do
    GenServer.call(__MODULE__, {:run, fun}, :infinity)
  end

  @doc """
  Whether a transcription is running right now. Read from ETS, not a call —
  a call would queue behind the very transcription being asked about.
  Busy-state changes are also broadcast; see
  `EarWitness.Transcription.subscribe_activity/0`.
  """
  @spec busy?() :: boolean()
  def busy? do
    :ets.lookup(@busy_table, :busy) == [busy: true]
  rescue
    # Table owner (this gate) isn't running — nothing can be transcribing.
    ArgumentError -> false
  end

  @impl true
  def init(nil) do
    :ets.new(@busy_table, [:named_table, :public, read_concurrency: true])
    {:ok, nil}
  end

  @impl true
  def handle_call({:run, fun}, _from, state) do
    set_busy(true)

    result =
      try do
        fun.()
      rescue
        error -> {:error, Exception.message(error)}
      catch
        :exit, reason -> {:error, "transcription crashed: #{inspect(reason)}"}
      end

    set_busy(false)
    {:reply, result, state}
  end

  defp set_busy(busy) do
    :ets.insert(@busy_table, {:busy, busy})
    EarWitness.Transcription.broadcast_activity(busy)
  end
end
