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
  Advances the bot session identified by `session_id` through a full,
  successful run — joins the meeting, records it, leaves, and hands the
  audio off to the local library, exactly as a real completed bot
  session would (story 869, criteria 7385 "The meeting shows up in the
  library afterwards", 7386 "Bot recordings get transcripts and
  speakers automatically", and 7389 "External components never keep
  the conversation"). Actually joining a real meeting is not something
  any spec can drive — there is no real external meeting to join — so
  this drives the same `EarWitness.Bots` calls the real
  `EarWitness.Bots.Runner` would make once it had one: mark the session
  recording, deposit fixture audio as a `"bot"`-sourced recording, run
  it through the normal transcription pipeline, then complete the
  session.
  """
  def simulate_bot_join_completed(session_id) do
    {:ok, _session} = EarWitness.Bots.mark_recording(session_id)

    wav = bot_recording_wav()
    {:ok, header} = EarWitness.Recordings.WavHeader.parse(wav)
    path = Path.join(EarWitness.recordings_dir(), Ecto.UUID.generate() <> ".wav")
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, wav)

    {:ok, recording} =
      EarWitness.Recordings.create_recording(%{
        title: "Bot meeting recording",
        source: :bot,
        file_path: path,
        duration: header.duration_seconds
      })

    {:ok, _transcript} = EarWitness.Transcription.transcribe(recording)
    {:ok, _session} = EarWitness.Bots.complete_bot_session(session_id, recording.id)

    :ok
  end

  @doc """
  Advances the bot session identified by `session_id` to "joined and
  actively recording, meeting still underway" — the precondition for
  testing that a user can pull the bot back out before it would finish
  on its own (story 869, criterion 7387 — "Recall the bot
  mid-meeting"). Drives the same `EarWitness.Bots.mark_recording/1` call
  the real `EarWitness.Bots.Runner` makes on a successful join.
  """
  def simulate_bot_actively_recording(session_id) do
    {:ok, _session} = EarWitness.Bots.mark_recording(session_id)
    :ok
  end

  @doc """
  Advances the bot session identified by `session_id` to a failed join
  outcome because the meeting's waiting room rejected it, the way a
  host declining to admit the bot would (story 869, criterion 7388 —
  "Waiting-room rejection is reported, not swallowed"). Drives the same
  `EarWitness.Bots.fail_bot_session/2` call the real
  `EarWitness.Bots.Runner` makes on a rejected join.
  """
  def simulate_bot_waiting_room_rejection(session_id) do
    {:ok, _session} =
      EarWitness.Bots.fail_bot_session(
        session_id,
        "The meeting's waiting room did not admit the bot."
      )

    :ok
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
