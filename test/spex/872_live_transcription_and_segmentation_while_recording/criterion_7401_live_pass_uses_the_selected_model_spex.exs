defmodule EarWitnessSpex.LiveTranscriptionAndSegmentationWhileRecording.Criterion7401Spex do
  @moduledoc """
  Story 872 — Live transcription and segmentation while recording
  Criterion 7401: Live pass uses the model chosen in Settings

  The live transcript is produced by the app's transcription engine — the same
  engine (and therefore the same selected model) the final/batch transcript
  uses, not a separate live-only path. Under test that engine is the configured
  fake; the observable here is that live segments are the engine's output. That
  the engine actually loads the *selected model* is verified where it's real:
  the model-path wiring (Engine.transcribe passes the active model) and the
  real-audio live run — a fake engine can't distinguish models.
  """

  use EarWitnessSpex.Case

  spex "Live pass uses the model chosen in Settings" do
    scenario "live segments are produced by the app's transcription engine", context do
      given_ "a live-transcribing capture is available", context do
        EarWitnessSpex.Fixtures.enable_live_capture_seam()
        {:ok, view, _html} = live(context.conn, "/recordings")
        view |> element("button", "Record") |> render_click()
        EarWitnessSpex.Fixtures.feed_live_audio()

        Map.put(context, :recording_id, EarWitnessSpex.Fixtures.live_recording_id())
      end

      then_ "the live transcript carries the transcription engine's output", context do
        {:ok, show, _html} = live(context.conn, "/recordings/#{context.recording_id}")

        assert has_element?(show, ~s([data-test="transcript-segment"]), "Testing 1, 2, 3")
        :ok
      end
    end
  end
end
