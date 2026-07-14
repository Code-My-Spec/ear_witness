defmodule EarWitnessSpex.TranscribeAHearingRecordingLocally.Criterion7325Spex do
  @moduledoc """
  Story 860 — Transcribe a hearing recording locally
  Criterion 7325: No input device available
  """

  use EarWitnessSpex.Case

  spex "No input device available" do
    scenario "hearing documenter tries to record with no capture device at all",
             context do
      given_ "the recordings library is open on a machine with no mic and no system-audio tap",
              context do
        # Capture now records mic + system audio together and falls back to
        # whichever single source exists, so "no input device" means BOTH are
        # unavailable — no microphone and no tap.
        EarWitnessSpex.Fixtures.simulate_no_input_devices()
        EarWitnessSpex.Fixtures.simulate_tap_not_installed()
        {:ok, view, _html} = live(context.conn, "/recordings")
        Map.put(context, :view, view)
      end

      when_ "they try to start a live recording", context do
        html = context.view |> element("button", "Record") |> render_click()
        Map.put(context, :html, html)
      end

      then_ "they see a message that no input device is available", context do
        assert has_element?(context.view, ~s([data-test="capture-error"]))
        assert context.html =~ "No input device"
        :ok
      end

      then_ "no recording is added to the library", context do
        refute has_element?(context.view, ~s([data-test="recording-row"]))
        :ok
      end
    end
  end
end
