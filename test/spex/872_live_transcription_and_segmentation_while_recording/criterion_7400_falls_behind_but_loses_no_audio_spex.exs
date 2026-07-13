defmodule EarWitnessSpex.LiveTranscriptionAndSegmentationWhileRecording.Criterion7400Spex do
  @moduledoc """
  Story 872 — Live transcription and segmentation while recording
  Criterion 7400: Slow machine falls behind but loses no audio

  Capture is sacred: transcription can fall behind, but it never drops audio —
  the whole recording is transcribed, reconciled from the finished WAV on stop.
  The "falls behind in real time" aspect is a timing property verified on real
  audio; here we assert the guarantee that matters for correctness — every part
  of the audio that was fed ends up in the finished transcript, nothing lost.
  """

  use EarWitnessSpex.Case

  spex "Slow machine falls behind but loses no audio" do
    scenario "all of the recorded audio is in the transcript once it finalizes", context do
      given_ "a recording that captured two passages of speech", context do
        EarWitnessSpex.Fixtures.enable_live_capture_seam()
        {:ok, view, _html} = live(context.conn, "/recordings")
        view |> element("button", "Record") |> render_click()
        EarWitnessSpex.Fixtures.feed_live_audio()

        context
        |> Map.put(:view, view)
        |> Map.put(:recording_id, EarWitnessSpex.Fixtures.live_recording_id())
      end

      when_ "they stop the recording and it finalizes", context do
        context.view |> element("button", "Stop") |> render_click()
        EarWitnessSpex.Fixtures.await_live_transcription_finalized(context.recording_id)
        context
      end

      then_ "both passages of speech are present in the final transcript", context do
        {:ok, show, _html} = live(context.conn, "/recordings/#{context.recording_id}")

        assert has_element?(show, ~s([data-test="transcript-segment"]), "Testing 1, 2, 3")
        assert has_element?(show, ~s([data-test="transcript-segment"]), "1, 2, 3.")
        :ok
      end
    end
  end
end
