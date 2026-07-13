defmodule EarWitnessSpex.LiveTranscriptionAndSegmentationWhileRecording.Criterion7398Spex do
  @moduledoc """
  Story 872 — Live transcription and segmentation while recording
  Criterion 7398: Stopping diarizes the live transcript instead of re-transcribing

  The transcript built live IS the canonical transcript: the text a user
  watched appear live is exactly the text that remains after stopping — stop
  adds speaker labels via diarization, it does not throw the live transcript
  away and transcribe the audio a second time.
  """

  use EarWitnessSpex.Case

  spex "Stopping diarizes the live transcript instead of re-transcribing" do
    scenario "the text seen live remains after stop, now attributed to speakers", context do
      given_ "a recording whose live transcript the user watched stream in", context do
        EarWitnessSpex.Fixtures.enable_live_capture_seam()
        {:ok, view, _html} = live(context.conn, "/recordings")
        view |> element("button", "Record") |> render_click()
        EarWitnessSpex.Fixtures.feed_live_audio()

        context
        |> Map.put(:view, view)
        |> Map.put(:recording_id, EarWitnessSpex.Fixtures.live_recording_id())
      end

      then_ "the live text is present before stopping", context do
        {:ok, show, _html} = live(context.conn, "/recordings/#{context.recording_id}")
        assert has_element?(show, ~s([data-test="transcript-segment"]), "Testing 1, 2, 3")
        :ok
      end

      when_ "they stop the recording and it finalizes", context do
        context.view |> element("button", "Stop") |> render_click()
        EarWitnessSpex.Fixtures.await_live_transcription_finalized(context.recording_id)
        context
      end

      then_ "that same text is still the transcript, now with speaker labels", context do
        {:ok, show, _html} = live(context.conn, "/recordings/#{context.recording_id}")

        assert has_element?(show, ~s([data-test="transcript-segment"]), "Testing 1, 2, 3")
        assert has_element?(show, ~s([data-test="segment-speaker"]))
        :ok
      end
    end
  end
end
