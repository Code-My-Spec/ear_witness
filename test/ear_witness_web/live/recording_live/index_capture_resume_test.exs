defmodule EarWitnessWeb.RecordingLive.IndexCaptureResumeTest do
  use EarWitnessTest.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias EarWitness.Transcription

  setup tags do
    EarWitnessTest.DataCase.setup_sandbox(tags)
    :ok
  end

  test "a remounted recordings view picks a running capture back up and can stop it", %{
    conn: conn
  } do
    EarWitnessSpex.Fixtures.enable_live_capture_seam()

    {:ok, first, _html} = live(conn, "/recordings")
    first |> element("button", "Record") |> render_click()
    recording_id = EarWitnessSpex.Fixtures.live_recording_id()

    # A fresh mount — what a live-reload, navigation, or LV crash produces —
    # must show the running capture, not an idle Record button.
    {:ok, second, _html} = live(conn, "/recordings")
    assert has_element?(second, ~s([data-test="capture-status"]))
    refute has_element?(second, ~s(button[phx-click="stop"][disabled]))
    assert has_element?(second, ~s(button[phx-click="record"][disabled]))

    # And it must be able to actually stop the orphaned capture.
    second |> element("button", "Stop") |> render_click()
    refute has_element?(second, ~s([data-test="capture-status"]))

    EarWitnessSpex.Fixtures.await_live_transcription_finalized(recording_id)
    {:ok, transcript} = Transcription.get_transcript_for_recording(recording_id)
    assert transcript.status == :completed
  end

  test "a second view can't start a second capture — it picks up the running one", %{
    conn: conn
  } do
    EarWitnessSpex.Fixtures.enable_live_capture_seam()

    # The Captures agent may hold stale entries from earlier tests that never
    # drove Stop — measure this test's delta, not the absolute size.
    baseline = map_size(EarWitness.Audio.Captures.all())

    {:ok, first, _html} = live(conn, "/recordings")
    first |> element("button", "Record") |> render_click()

    # Second view mounts idle-looking only if rehydration failed; either way,
    # Record must not start a second device capture.
    {:ok, second, _html} = live(conn, "/recordings")

    if has_element?(second, ~s|button[phx-click="record"]:not([disabled])|) do
      second |> element("button", "Record") |> render_click()
    end

    assert map_size(EarWitness.Audio.Captures.all()) == baseline + 1
  end

  test "a view whose capture was stopped elsewhere clears its recording state", %{conn: conn} do
    EarWitnessSpex.Fixtures.enable_live_capture_seam()

    {:ok, first, _html} = live(conn, "/recordings")
    first |> element("button", "Record") |> render_click()
    recording_id = EarWitnessSpex.Fixtures.live_recording_id()

    # Second view rehydrates the running capture...
    {:ok, second, _html} = live(conn, "/recordings")
    assert has_element?(second, ~s([data-test="capture-status"]))

    # ...then the FIRST view stops it. The second must drop its recording
    # badge/Stop button once the :completed broadcast lands.
    first |> element("button", "Stop") |> render_click()
    EarWitnessSpex.Fixtures.await_live_transcription_finalized(recording_id)

    render(second)
    refute has_element?(second, ~s([data-test="capture-status"]))
    assert has_element?(second, ~s|button[phx-click="record"]:not([disabled])|)
  end

  test "record is disabled with a notice while an earlier transcription runs", %{conn: conn} do
    alias EarWitness.Transcription.Gate

    # Occupy the gate with a job we control — stands in for an Oban job
    # resumed at boot, still transcribing an earlier recording.
    gate_job = Task.async(fn -> Gate.run(fn -> receive do: (:finish -> {:ok, []}) end) end)
    wait_until(fn -> Gate.busy?() end)

    {:ok, view, _html} = live(conn, "/recordings")
    assert has_element?(view, ~s([data-test="transcription-busy"]))
    assert has_element?(view, ~s(button[phx-click="record"][disabled]))

    send(Process.whereis(Gate), :finish)
    assert {:ok, []} = Task.await(gate_job)

    # busy: false is broadcast before the gate replies, so it's already in
    # the view's mailbox; render/1 processes it.
    render(view)
    refute has_element?(view, ~s([data-test="transcription-busy"]))
    refute has_element?(view, ~s(button[phx-click="record"][disabled]))
  end

  defp wait_until(fun, deadline_ms \\ 1_000) do
    if fun.() do
      :ok
    else
      if deadline_ms <= 0, do: flunk("condition never became true")
      Process.sleep(10)
      wait_until(fun, deadline_ms - 10)
    end
  end

  test "fail_orphaned_transcripts marks stuck :transcribing transcripts failed" do
    {:ok, recording} =
      EarWitness.Recordings.create_recording(%{
        title: "orphan.wav",
        source: :captured,
        capture_source: :microphone,
        file_path: "/nonexistent/orphan.wav",
        duration: 0.0
      })

    {:ok, transcript} = Transcription.create_live_transcript(recording.id)
    assert transcript.status == :transcribing

    assert Transcription.fail_orphaned_transcripts() == 1

    {:ok, reloaded} = Transcription.get_transcript_for_recording(recording.id)
    assert reloaded.status == :failed
  end
end
