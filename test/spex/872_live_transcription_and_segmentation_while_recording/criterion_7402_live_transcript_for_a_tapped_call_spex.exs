defmodule EarWitnessSpex.LiveTranscriptionAndSegmentationWhileRecording.Criterion7402Spex do
  @moduledoc """
  Story 872 — Live transcription and segmentation while recording
  Criterion 7402: Live transcript for a tapped call

  Live transcription is capture-source agnostic: recording through the
  system-audio tap streams a live transcript exactly as a microphone recording
  does. The tap is selected through the real settings UI; the `:fixture_live`
  seam reports it installed so the selection succeeds under test.
  """

  use EarWitnessSpex.Case

  spex "Live transcript for a tapped call" do
    scenario "recording through the system-audio tap streams a live transcript", context do
      given_ "the system-audio tap is the active capture source", context do
        EarWitnessSpex.Fixtures.enable_live_capture_seam()
        EarWitnessSpex.SettingsSteps.choose_tap_capture_source(context.conn)
        context
      end

      when_ "they record a call through the tap and it is transcribed", context do
        {:ok, view, _html} = live(context.conn, "/recordings")
        view |> element("button", "Record") |> render_click()
        EarWitnessSpex.Fixtures.feed_live_audio()

        Map.put(context, :recording_id, EarWitnessSpex.Fixtures.live_recording_id())
      end

      then_ "the call's speech appears as live transcript segments", context do
        {:ok, show, _html} = live(context.conn, "/recordings/#{context.recording_id}")

        assert has_element?(show, ~s([data-test="transcript-segment"]), "Testing 1, 2, 3")
        :ok
      end
    end
  end
end
