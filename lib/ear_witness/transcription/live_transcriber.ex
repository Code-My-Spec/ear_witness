defmodule EarWitness.Transcription.LiveTranscriber do
  @moduledoc """
  Transcribes an in-progress capture live (story 872). Started when a real
  device-backed capture begins (see `EarWitness.Recordings.start_live_capture/0`),
  one per capture, under `EarWitness.Transcription.LiveSupervisor` and keyed by
  the capture `ref` in `EarWitness.Transcription.LiveRegistry`.

  ## How it works

  The capture NIF writes nothing to the WAV until stop, so this drains the
  in-memory PCM every #{1_500}ms via `EarWitness.Audio.Miniaudio.read_new/1`
  into a rolling buffer. Once ~20s of new audio has accumulated it writes that
  window to a temp 16kHz-mono-PCM16 WAV (the same format the recording's own
  file uses — see `transcribe_pcm/2`), runs it through the active transcription
  engine (`config :ear_witness, :transcription_engine` — the same model the
  final transcript uses), offsets the returned segment timestamps by
  the window's absolute start, and appends the finalized segments to the
  recording's transcript. A ~2s tail of each window is carried into the next as
  acoustic context so a word straddling the boundary isn't clipped; segments
  are de-duplicated by only committing those that start at/after the last
  committed segment's end.

  Capture is sacred: this runs in its own process, so if transcription can't
  keep up (or crashes) the capture keeps writing audio and the live transcript
  simply falls behind — it never drops audio, because it processes the whole
  backlog and, on stop, reconciles the tail from the finished WAV (the true
  source of the full recording) rather than from memory.

  ## On stop (`finalize/1`)

  Returns immediately; the rest happens in this background process:

    1. Transcribe everything from the last committed segment to the end of the
       finished WAV (the remaining backlog).
    2. Mark the transcript `:completed`.
    3. Run `EarWitness.Speakers.diarize_transcript/1` on the full recording, so
       speaker ids fill in after recording (never during — matches diarization-v1).

  ## Observability contract (for the recording UI)

  Segments are read the ordinary way, via
  `EarWitness.Transcription.get_transcript_for_recording/1`, at any time. State
  is observable through the transcript itself:

    * recording / finishing backlog — `status: :transcribing`, `diarized_at: nil`,
      segments streaming in with `speaker_id: nil`.
    * done — `status: :completed`, `diarized_at` set, every segment attributed.

  Each new batch of live segments, plus completion and post-diarization, emits
  `{:transcription_status, status}` on `"transcription:\#{recording_id}"` (via
  `EarWitness.Transcription.broadcast_status/2`) — the same message the Oban
  worker sends, so subscribers re-render without special-casing live capture.
  """

  use GenServer, restart: :temporary

  require Logger

  alias EarWitness.Audio.Miniaudio
  alias EarWitness.Recordings.WavHeader
  alias EarWitness.Speakers
  alias EarWitness.Transcription

  @registry EarWitness.Transcription.LiveRegistry
  @supervisor EarWitness.Transcription.LiveSupervisor

  @sample_rate 16_000
  @bytes_per_sample 2
  @channels 1
  @bits_per_sample 16

  # Drain the capture buffer this often. Small enough that "recording keeps
  # writing" is smooth, large enough to be negligible mutex contention.
  @drain_interval_ms 1_500
  # Transcribe once this much *new* audio has accumulated. Whisper is far more
  # accurate on a window of real length than on a second or two, and returns
  # nothing useful on very short clips — 20s is the balance the plan calls for.
  @window_samples 20 * @sample_rate
  # Acoustic lookback carried into the next window so a boundary word isn't
  # clipped; its segments are dropped by the de-dup rule (they start before the
  # last committed end), so it never double-counts.
  @carry_samples 2 * @sample_rate
  # Don't bother transcribing a sub-half-second final tail — whisper returns
  # noise or nothing from it.
  @min_final_samples div(@sample_rate, 2)

  # -- public API --------------------------------------------------------

  @doc """
  Starts a live transcriber under the dynamic supervisor. Required opts:
  `:ref` (capture ref — the registry key), `:handle` (native capture handle to
  drain), `:recording_id`, `:transcript_id`, and `:path` (the capture's WAV
  file, read on stop to reconcile the tail). Accepts an optional `:engine`
  override (defaults to the configured transcription engine).
  """
  @spec start(keyword()) :: DynamicSupervisor.on_start_child()
  def start(opts) do
    DynamicSupervisor.start_child(@supervisor, {__MODULE__, opts})
  end

  @doc "Whether a live transcriber is running for a capture `ref`."
  @spec running?(reference()) :: boolean()
  def running?(ref), do: Registry.lookup(@registry, ref) != []

  @doc """
  Stops live draining and finalizes in the background: transcribes the
  remaining backlog from the finished WAV, marks the transcript complete, then
  diarizes. Returns `:ok` immediately (story 872 rule 7). A no-op if no live
  transcriber is running for `ref`.
  """
  @spec finalize(reference()) :: :ok
  def finalize(ref) do
    case Registry.lookup(@registry, ref) do
      [{pid, _}] -> GenServer.cast(pid, :finalize)
      [] -> :ok
    end
  end

  def start_link(opts) do
    ref = Keyword.fetch!(opts, :ref)
    GenServer.start_link(__MODULE__, opts, name: via(ref))
  end

  defp via(ref), do: {:via, Registry, {@registry, ref}}

  # -- GenServer ---------------------------------------------------------

  @impl true
  def init(opts) do
    state = %{
      ref: Keyword.fetch!(opts, :ref),
      handle: Keyword.fetch!(opts, :handle),
      recording_id: Keyword.fetch!(opts, :recording_id),
      transcript_id: Keyword.fetch!(opts, :transcript_id),
      path: Keyword.fetch!(opts, :path),
      engine: Keyword.get(opts, :engine, configured_engine()),
      # PCM not yet transcribed, covering samples [pending_start_sample, next_sample).
      pending: <<>>,
      pending_start_sample: 0,
      # Last ~2s of the previously transcribed window, prepended to the next
      # for context, covering [carry_start_sample, pending_start_sample).
      carry: <<>>,
      carry_start_sample: 0,
      next_sample: 0,
      last_committed_end_ms: 0
    }

    schedule_drain()
    {:ok, state}
  end

  @impl true
  def handle_info(:drain, state) do
    state = state |> drain() |> process_ready()
    schedule_drain()
    {:noreply, state}
  end

  @impl true
  def handle_cast(:finalize, state) do
    # Heavy work runs here (in this dedicated process) so the caller's cast
    # returned immediately. No more draining after this — the process stops.
    do_finalize(state)
    {:stop, :normal, state}
  end

  defp schedule_drain, do: Process.send_after(self(), :drain, @drain_interval_ms)

  # Pull whatever the capture has produced since last time into `pending`.
  # Never lets a transient read error stall the loop — it just tries again.
  defp drain(state) do
    case Miniaudio.read_new(state.handle) do
      {:ok, pcm} when byte_size(pcm) > 0 ->
        %{
          state
          | pending: state.pending <> pcm,
            next_sample: state.next_sample + div(byte_size(pcm), @bytes_per_sample)
        }

      _ ->
        state
    end
  end

  # Transcribe full windows as long as enough new audio has piled up (so a
  # backlog is worked down one bounded window at a time rather than one giant
  # whisper call), leaving the remainder in `pending`.
  defp process_ready(state) do
    if div(byte_size(state.pending), @bytes_per_sample) >= @window_samples do
      state |> transcribe_window(@window_samples) |> process_ready()
    else
      state
    end
  end

  defp transcribe_window(state, take_samples) do
    take_bytes = take_samples * @bytes_per_sample
    <<take::binary-size(^take_bytes), rest::binary>> = state.pending

    window_pcm = state.carry <> take

    window_start_sample =
      if state.carry == <<>>, do: state.pending_start_sample, else: state.carry_start_sample

    last_end = commit_window(state, window_pcm, window_start_sample)

    take_end_sample = state.pending_start_sample + take_samples
    carry_len = min(@carry_samples, take_samples)
    new_carry = binary_part(take, take_bytes - carry_len * @bytes_per_sample, carry_len * @bytes_per_sample)

    %{
      state
      | pending: rest,
        pending_start_sample: take_end_sample,
        carry: new_carry,
        carry_start_sample: take_end_sample - carry_len,
        last_committed_end_ms: last_end
    }
  end

  # Transcribes one window of PCM whose first sample is at absolute index
  # `window_start_sample`, commits the segments that begin at/after the last
  # committed end (the de-dup that makes the carry overlap free), broadcasts if
  # anything landed, and returns the new last-committed-end in ms.
  defp commit_window(state, window_pcm, window_start_sample) do
    window_start_ms = samples_to_ms(window_start_sample)

    case transcribe_pcm(state, window_pcm) do
      {:ok, documents} ->
        inserted = insert_new_segments(state, documents, window_start_ms)
        if inserted != [], do: Transcription.broadcast_status(state.recording_id, :transcribing)

        Enum.reduce(inserted, state.last_committed_end_ms, fn segment, acc ->
          max(acc, segment.end_offset)
        end)

      {:error, reason} ->
        Logger.warning("LiveTranscriber window transcribe failed: #{inspect(reason)}")
        state.last_committed_end_ms
    end
  end

  defp insert_new_segments(state, documents, window_start_ms) do
    documents
    |> Enum.flat_map(&Map.get(&1, "transcription", []))
    |> Enum.map(fn segment ->
      %{
        text: segment |> Map.get("text", "") |> String.trim(),
        start_offset: window_start_ms + (get_in(segment, ["offsets", "from"]) || 0),
        end_offset: window_start_ms + (get_in(segment, ["offsets", "to"]) || 0)
      }
    end)
    |> Enum.filter(&(&1.text != "" and &1.start_offset >= state.last_committed_end_ms))
    |> Enum.map(fn attrs ->
      {:ok, segment} = Transcription.append_segment(state.transcript_id, attrs)
      segment
    end)
  end

  # Writes the drained window to a temp 16kHz-mono-PCM16 WAV — the same format
  # the capture backends produce and `EarWitness.Transcription.Engine` reads for
  # the batch/import path — and runs the active engine on it (the engine seam
  # takes a path). The temp file is always cleaned up. Keeping this identical to
  # the recording's own on-disk format means live and final transcription go
  # through one audio format end to end.
  defp transcribe_pcm(state, pcm) do
    tmp =
      Path.join(
        System.tmp_dir!(),
        "live_#{state.transcript_id}_#{System.unique_integer([:positive])}.wav"
      )

    File.write!(tmp, wav(pcm))

    try do
      state.engine.transcribe(tmp)
    after
      File.rm(tmp)
    end
  end

  # -- stop / finalize ---------------------------------------------------

  defp do_finalize(state) do
    transcribe_backlog(state)
    {:ok, _transcript} = Transcription.complete_transcript(state.transcript_id)
    Transcription.broadcast_status(state.recording_id, :completed)
    diarize(state)
    Transcription.broadcast_status(state.recording_id, :completed)
  end

  # Transcribes everything the live windows never reached, read from the
  # finished WAV (the authoritative full recording) rather than memory — so the
  # tail is never lost even if live transcription fell far behind, and the
  # macOS tap's freed-on-stop buffer is irrelevant here.
  defp transcribe_backlog(state) do
    with {:ok, bytes} <- File.read(state.path),
         {:ok, pcm} <- WavHeader.data_bytes(bytes) do
      total_samples = div(byte_size(pcm), @bytes_per_sample)
      start_sample = max(0, ms_to_samples(state.last_committed_end_ms) - @carry_samples)

      if total_samples - start_sample >= @min_final_samples do
        window = binary_part(pcm, start_sample * @bytes_per_sample, byte_size(pcm) - start_sample * @bytes_per_sample)
        _ = commit_window(state, window, start_sample)
      end
    end
  end

  defp diarize(state) do
    case Transcription.get_transcript_for_recording(state.recording_id) do
      {:ok, transcript} -> Speakers.diarize_transcript(transcript)
      _ -> :ok
    end
  end

  # -- helpers -----------------------------------------------------------

  defp configured_engine do
    Application.get_env(:ear_witness, :transcription_engine, Transcription.Engine)
  end

  defp samples_to_ms(samples), do: div(samples * 1000, @sample_rate)
  defp ms_to_samples(ms), do: div(ms * @sample_rate, 1000)

  # 44-byte RIFF/WAVE wrapper — the exact 16kHz mono PCM16 layout the capture
  # backends emit and the engine reads (see transcribe_pcm/2).
  defp wav(data) do
    data_size = byte_size(data)
    block_align = @channels * div(@bits_per_sample, 8)
    byte_rate = @sample_rate * block_align

    <<"RIFF", 36 + data_size::little-32, "WAVE", "fmt ", 16::little-32, 1::little-16,
      @channels::little-16, @sample_rate::little-32, byte_rate::little-32, block_align::little-16,
      @bits_per_sample::little-16, "data", data_size::little-32, data::binary>>
  end
end
