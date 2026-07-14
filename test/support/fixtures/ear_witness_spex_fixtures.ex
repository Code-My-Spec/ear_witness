defmodule EarWitnessSpex.Fixtures do
  @moduledoc """
  Curated bridge from BDD specs into in-app state.

  The only module that may dep on `EarWitness` from inside the spex test
  tree. Declared as its own top-level Boundary so the spec boundary can dep
  on it without inheriting `EarWitness`'s deps.
  """

  use Boundary, top_level?: true, deps: [EarWitness]

  # --- Add re-exports below as specs need them. Keep the list small; every
  # export here is a sanctioned shortcut past the UI. ---
  #
  # Planned (uncomment as the contexts land — see architecture proposal):
  #
  #   defdelegate recording_fixture(attrs \\ %{}), to: EarWitness.Recordings
  #     # a completed recording on disk + Recording row, so transcript specs
  #     # don't have to drive a live capture first
  #
  #   defdelegate transcript_fixture(recording, attrs \\ %{}),
  #     to: EarWitness.Transcription
  #     # a finished transcript, so search/read specs skip the whisper run

  @doc """
  Makes the capture layer report zero available input devices for the
  current test (spec 7325 — "No input device available"). Overrides
  `EarWitness.Audio.Pipeline.input_devices/0` for the duration of the
  current test only.
  """
  def simulate_no_input_devices do
    Application.put_env(:ear_witness, :capture_devices_override, [])

    ExUnit.Callbacks.on_exit(fn ->
      Application.delete_env(:ear_witness, :capture_devices_override)
    end)
  end

  @doc """
  Makes the capture layer report that the system audio tap is not set up on
  this machine (spec 7338 — guided setup). Overrides
  `EarWitness.Audio.Tap.installed?/0` for the duration of the current test
  only.
  """
  def simulate_tap_not_installed do
    Application.put_env(:ear_witness, :tap_installed_override, false)

    ExUnit.Callbacks.on_exit(fn ->
      Application.delete_env(:ear_witness, :tap_installed_override)
    end)
  end

  @doc """
  Makes announce-policy notice delivery fail for the current test (story
  861 spec 7337 — capture refused when the policy's conditions are unmet;
  story 867 spec 7373 — capture refused when the policy cannot be
  satisfied, the same underlying behavior viewed from the recording-law
  story). Overrides `EarWitness.Audio.ConsentPolicy.authorize/1` for the
  duration of the current test only.
  """
  def simulate_announcement_delivery_failure do
    Application.put_env(:ear_witness, :announcement_delivery_override, :fail)

    ExUnit.Callbacks.on_exit(fn ->
      Application.delete_env(:ear_witness, :announcement_delivery_override)
    end)
  end

  @doc """
  Establishes `name` as an already-known speaker with a stored voice
  signature (an embedding centroid accumulated from a prior recording) —
  the precondition for specs asserting that the *next* recording either
  recognizes that voice automatically (story 862, criterion 7341) or, after
  the signature is deleted, no longer recognizes it (criterion 7344).

  Drives a full round trip through the real `EarWitness.Speakers.Diarizer`
  seam: creates a seed recording, transcribes it, diarizes it (which
  creates a fresh, unnamed `Speaker` carrying a real voice-embedding
  centroid — see `EarWitness.Speakers.diarize_transcript/1`), then names
  that speaker `name`, exactly as a user would after their first
  recording of this person. Titling the seed recording
  `*-with-\#{name}.wav` matters: every `"*-meeting-with-\#{name}.wav"`
  recording a spec imports afterward replays the same `known_voice`
  diarizer cassette (see `EarWitnessTest.RecordedDiarizer`), so its
  first turn's embedding genuinely cosine-matches this speaker's stored
  centroid rather than being faked into matching.
  """
  def simulate_known_speaker_with_voice_signature(name) do
    path = Path.join(EarWitness.recordings_dir(), Ecto.UUID.generate() <> ".wav")
    File.mkdir_p!(Path.dirname(path))
    wav = bot_recording_wav()
    File.write!(path, wav)
    {:ok, header} = EarWitness.Recordings.WavHeader.parse(wav)

    {:ok, recording} =
      EarWitness.Recordings.create_recording(%{
        title: "voice-signature-seed-with-#{name}.wav",
        source: :imported,
        file_path: path,
        duration: header.duration_seconds
      })

    {:ok, _transcript} = EarWitness.Transcription.transcribe(recording)
    {:ok, transcript} = EarWitness.Transcription.get_transcript_for_recording(recording.id)
    :ok = EarWitness.Speakers.diarize_transcript(transcript)
    {:ok, transcript} = EarWitness.Transcription.get_transcript_for_recording(recording.id)

    [first_segment | _] = transcript.segments
    {:ok, _speaker} = EarWitness.Speakers.rename_speaker(first_segment.speaker_id, name)

    :ok
  end

  @doc """
  No-op: `EarWitness.Speakers.Diarizer` now really exists, and any
  recording titled `"two-person-hearing.wav"` genuinely diarizes to two
  distinct detected speakers once transcribed (see
  `EarWitnessTest.RecordedDiarizer`'s `two_speakers` cassette) — nothing
  needs to be staged ahead of the real transcribe flow anymore. Kept
  (rather than deleted) so story 863's criterion 7346 spec doesn't need
  to change shape now that its precondition is honestly satisfiable
  through the real seam.
  """
  def simulate_two_speakers_detected, do: :ok

  @doc """
  Interrupts an in-progress model download partway through, the way a
  real network drop would (spec 7369 — "Network drop mid-download
  recovers cleanly"). Injecting a genuine dropped connection isn't
  stageable through the real UI, so this flips a one-shot override that
  `EarWitness.Models.Downloader` consumes on its very next transfer
  attempt, failing it with `:network_interrupted` before it ever reaches
  the network — the retry that follows goes through the real download
  seam (replayed via `ReqCassette`, see `config/test.exs`) and verifies
  normally.
  """
  def simulate_download_network_interruption do
    Application.put_env(:ear_witness, :models_downloader_network_override, :interrupt)

    ExUnit.Callbacks.on_exit(fn ->
      Application.delete_env(:ear_witness, :models_downloader_network_override)
    end)
  end

  @doc """
  Holds model-download transfers genuinely in flight (story 866,
  criterion 7368) until `release_model_downloads/0` — like a real
  multi-gigabyte model on a slow connection. Registers an `on_exit`
  release so a spec can never leak a held gate.
  """
  def hold_model_downloads do
    ExUnit.Callbacks.on_exit(fn -> __MODULE__.GatedDownloadPlug.release() end)
    __MODULE__.GatedDownloadPlug.hold()
  end

  @doc "Releases transfers held by `hold_model_downloads/0`."
  def release_model_downloads do
    __MODULE__.GatedDownloadPlug.release()
  end

  # --- Live transcription (story 872) spec seam ---------------------------
  #
  # Fixture captures normally skip live transcription (no device handle), so
  # these enable a deterministic, no-real-audio path: a spec drives the real
  # Record button, pushes controllable audio that the fake engine turns into
  # known segments, then Stop, and asserts on the rendered transcript.
  #
  # Usage sketch (a spec drives Record/Stop/Show through the LiveView itself):
  #
  #   EarWitnessSpex.Fixtures.enable_live_capture_seam()      # in given_
  #   view |> element("button", "Record") |> render_click()  # real UI
  #   EarWitnessSpex.Fixtures.feed_live_audio()               # -> 2 live segments
  #   id = EarWitnessSpex.Fixtures.live_recording_id()
  #   # ...navigate to /recordings/#{id}, assert segment text, NO speakers...
  #   view |> element("button", "Stop") |> render_click()     # real UI
  #   EarWitnessSpex.Fixtures.await_live_transcription_finalized(id)
  #   # ...navigate to /recordings/#{id}, assert speaker labels now present...

  @doc """
  Switches capture to the `:fixture_live` seam for the current test: real
  `Recordings.start_live_capture/0` now starts the `LiveTranscriber` (a fixture
  capture is skipped), draining `#{inspect(__MODULE__)}.FakeCaptureReader`
  instead of a device. Resets the reader queue and restores the prior capture
  source on exit. Call once, before driving the Record button.
  """
  def enable_live_capture_seam do
    previous = Application.get_env(:ear_witness, :capture_source)
    Application.put_env(:ear_witness, :capture_source, :fixture_live)

    # Kill live transcribers a previous test left running (a scenario that
    # never drives Stop leaves its transcriber alive). The reader below is one
    # shared queue — flush_live_transcribers/0 flushes every child, so a stale
    # transcriber can otherwise steal the audio this test pushes.
    EarWitness.Transcription.LiveSupervisor
    |> DynamicSupervisor.which_children()
    |> Enum.each(fn
      {_, pid, _, _} when is_pid(pid) ->
        DynamicSupervisor.terminate_child(EarWitness.Transcription.LiveSupervisor, pid)

      _ ->
        :ok
    end)

    __MODULE__.FakeCaptureReader.reset()

    ExUnit.Callbacks.on_exit(fn ->
      Application.put_env(:ear_witness, :capture_source, previous)
    end)

    :ok
  end

  @doc """
  Pushes audio into the running live capture and synchronously transcribes it,
  so the segments are on the transcript when this returns. `seconds` defaults to
  exactly one transcription window — one batch of the fake engine's segments
  (its default cassette: "Testing 1, 2, 3, testing." at 0-3000ms and "1, 2, 3."
  at 3000-8000ms). The audio itself is silence; the fake engine maps window ->
  known text deterministically regardless of content.
  """
  def feed_live_audio(seconds \\ nil) do
    bytes =
      case seconds do
        nil -> EarWitness.Transcription.LiveTranscriber.window_bytes()
        s -> round(s * 16_000) * 2
      end

    __MODULE__.FakeCaptureReader.push(:binary.copy(<<0>>, bytes))
    flush_live_transcribers()
    :ok
  end

  @doc """
  The id of the recording the live capture created at start (the most recent
  recording) — for navigating to `/recordings/:id` to observe live segments.
  """
  def live_recording_id do
    case EarWitness.Recordings.list_recordings() do
      [%{id: id} | _] -> id
      [] -> nil
    end
  end

  @doc """
  Blocks until a stopped live recording's background finalize + diarization has
  completed — transcript `:completed` with `diarized_at` set (speakers filled
  in) — or the timeout elapses. Call after driving Stop, before asserting on
  speaker labels.
  """
  def await_live_transcription_finalized(recording_id, timeout_ms \\ 2_000) do
    wait_finalized(recording_id, System.monotonic_time(:millisecond) + timeout_ms)
  end

  defp wait_finalized(recording_id, deadline) do
    case EarWitness.Transcription.get_transcript_for_recording(recording_id) do
      {:ok, %{status: :completed, diarized_at: diarized_at}} when not is_nil(diarized_at) ->
        :ok

      _ ->
        if System.monotonic_time(:millisecond) < deadline do
          Process.sleep(10)
          wait_finalized(recording_id, deadline)
        else
          {:error, :timeout}
        end
    end
  end

  defp flush_live_transcribers do
    EarWitness.Transcription.LiveSupervisor
    |> DynamicSupervisor.which_children()
    |> Enum.each(fn
      {_, pid, _, _} when is_pid(pid) -> EarWitness.Transcription.LiveTranscriber.flush(pid)
      _ -> :ok
    end)
  end

  # A minimal, valid mono 16-bit PCM WAV file as an in-memory binary — same
  # construction as EarWitnessSpex.WavFixture.short/0, duplicated rather than
  # reused because this boundary may not dep on EarWitnessSpex (see moduledoc).
  defp bot_recording_wav do
    sample_rate = 16_000
    num_samples = 1_600
    channels = 1
    bits_per_sample = 16
    block_align = channels * div(bits_per_sample, 8)
    byte_rate = sample_rate * block_align

    data = :binary.copy(<<0::little-16>>, num_samples)
    data_size = byte_size(data)
    riff_size = 36 + data_size

    <<
      "RIFF",
      riff_size::little-32,
      "WAVE",
      "fmt ",
      16::little-32,
      1::little-16,
      channels::little-16,
      sample_rate::little-32,
      byte_rate::little-32,
      block_align::little-16,
      bits_per_sample::little-16,
      "data",
      data_size::little-32
    >> <> data
  end
end
