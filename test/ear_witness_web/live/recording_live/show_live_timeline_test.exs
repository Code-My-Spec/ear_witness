defmodule EarWitnessWeb.RecordingLive.ShowLiveTimelineTest do
  use EarWitnessTest.ConnCase, async: false

  import Phoenix.LiveViewTest

  setup tags do
    EarWitnessTest.DataCase.setup_sandbox(tags)
    :ok
  end

  test "live capture shows a timeline bar with the transcription head", %{conn: conn} do
    EarWitnessSpex.Fixtures.enable_live_capture_seam()

    {:ok, index, _html} = live(conn, "/recordings")
    index |> element("button", "Record") |> render_click()
    recording_id = EarWitnessSpex.Fixtures.live_recording_id()

    # Subscribe (mount the show view) BEFORE audio arrives — live progress is
    # broadcast, not persisted, so only an already-open view receives it.
    {:ok, show, html} = live(conn, "/recordings/#{recording_id}")
    refute html =~ "data-test=\"live-timeline\""

    # One full 20s window: the fake engine commits segments ending at 8000ms,
    # so the head sits at 8s of 20s captured.
    EarWitnessSpex.Fixtures.feed_live_audio()

    html = render(show)
    assert html =~ "data-test=\"live-timeline\""
    assert has_element?(show, ~s([data-test="live-timeline-bar"][value="8000"][max="20000"]))
    assert has_element?(show, ~s([data-test="live-timeline-head"]), "0:08")
    assert has_element?(show, ~s([data-test="live-timeline-captured"]), "0:20")
  end
end
