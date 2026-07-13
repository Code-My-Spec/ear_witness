defmodule EarWitnessSpex.LiveTranscriptionAndSegmentationWhileRecording.Criterion7397Spex do
  @moduledoc """
  Story 872 — Live transcription and segmentation while recording
  Criterion 7397: Segments show up while still recording

  Live transcription runs behind the `:fixture_live` capture seam
  (`EarWitnessSpex.Fixtures.enable_live_capture_seam/0`): the spec drives the
  real Record button, pushes controllable audio the fake engine turns into
  known segments, and asserts they render on the recording *before* Stop —
  i.e. while capture is still in progress.
  """

  use EarWitnessSpex.Case

  spex "Segments show up while still recording" do
    scenario "spoken text becomes a transcript segment while capture is still running", context do
      given_ "a live-transcribing capture is available", context do
        EarWitnessSpex.Fixtures.enable_live_capture_seam()
        {:ok, view, _html} = live(context.conn, "/recordings")
        Map.put(context, :view, view)
      end

      when_ "they start recording and speak", context do
        context.view |> element("button", "Record") |> render_click()
        EarWitnessSpex.Fixtures.feed_live_audio()
        Map.put(context, :recording_id, EarWitnessSpex.Fixtures.live_recording_id())
      end

      then_ "the spoken text is on the transcript while the recording is still in progress", context do
        {:ok, show, _html} = live(context.conn, "/recordings/#{context.recording_id}")

        assert has_element?(show, ~s([data-test="transcript-segment"]), "Testing 1, 2, 3")
        # Still recording, not stopped: the transcript is mid-flight, not completed.
        refute has_element?(show, ~s([data-test="open-editor-link"]))
        :ok
      end
    end
  end
end
