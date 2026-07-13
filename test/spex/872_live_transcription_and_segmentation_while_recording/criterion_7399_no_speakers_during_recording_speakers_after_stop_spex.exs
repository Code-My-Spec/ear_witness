defmodule EarWitnessSpex.LiveTranscriptionAndSegmentationWhileRecording.Criterion7399Spex do
  @moduledoc """
  Story 872 — Live transcription and segmentation while recording
  Criterion 7399: No speakers during recording, speakers after stop

  Diarization is post-hoc (diarization-v1): live segments carry no speaker
  while recording, and speaker labels appear only once the recording has
  stopped and its background finalize + diarization has run.
  """

  use EarWitnessSpex.Case

  spex "No speakers during recording, speakers after stop" do
    scenario "a live segment shows no speaker until the recording is stopped and diarized",
             context do
      given_ "a recording with a live segment already streamed in", context do
        EarWitnessSpex.Fixtures.enable_live_capture_seam()
        {:ok, view, _html} = live(context.conn, "/recordings")
        view |> element("button", "Record") |> render_click()
        EarWitnessSpex.Fixtures.feed_live_audio()

        context
        |> Map.put(:view, view)
        |> Map.put(:recording_id, EarWitnessSpex.Fixtures.live_recording_id())
      end

      then_ "while recording, the segment has no speaker label", context do
        {:ok, show, _html} = live(context.conn, "/recordings/#{context.recording_id}")

        assert has_element?(show, ~s([data-test="transcript-segment"]))
        refute has_element?(show, ~s([data-test="segment-speaker"]))
        :ok
      end

      when_ "they stop the recording and it finalizes", context do
        context.view |> element("button", "Stop") |> render_click()
        EarWitnessSpex.Fixtures.await_live_transcription_finalized(context.recording_id)
        context
      end

      then_ "every segment now carries a speaker label", context do
        {:ok, show, _html} = live(context.conn, "/recordings/#{context.recording_id}")

        assert has_element?(show, ~s([data-test="segment-speaker"]))
        :ok
      end
    end
  end
end
