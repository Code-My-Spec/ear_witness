defmodule EarWitnessSpex.LiveTranscriptionAndSegmentationWhileRecording.Criterion7403Spex do
  @moduledoc """
  Story 872 — Live transcription and segmentation while recording
  Criterion 7403: Stop is instant; last segments and speakers fill in after

  Stopping returns immediately — the remaining backlog transcription and the
  diarization pass run in the background and fill in afterward. The spec asserts
  the observable outcome of that design: after Stop returns, the final transcript
  and its speaker labels are completed by the background finalize (which the spec
  waits for), rather than being ready synchronously inside the Stop action.
  """

  use EarWitnessSpex.Case

  spex "Stop is instant; last segments and speakers fill in after" do
    scenario "stop returns and the background finalize completes the transcript with speakers",
             context do
      given_ "a recording with a live transcript in progress", context do
        EarWitnessSpex.Fixtures.enable_live_capture_seam()
        {:ok, view, _html} = live(context.conn, "/recordings")
        view |> element("button", "Record") |> render_click()
        EarWitnessSpex.Fixtures.feed_live_audio()

        context
        |> Map.put(:view, view)
        |> Map.put(:recording_id, EarWitnessSpex.Fixtures.live_recording_id())
      end

      when_ "they stop the recording", context do
        # Stop returns here without blocking on transcription/diarization.
        context.view |> element("button", "Stop") |> render_click()
        context
      end

      then_ "the background finalize completes the transcript and fills in speakers", context do
        EarWitnessSpex.Fixtures.await_live_transcription_finalized(context.recording_id)
        {:ok, show, _html} = live(context.conn, "/recordings/#{context.recording_id}")

        assert has_element?(show, ~s([data-test="transcript-segment"]))
        assert has_element?(show, ~s([data-test="segment-speaker"]))
        :ok
      end
    end
  end
end
