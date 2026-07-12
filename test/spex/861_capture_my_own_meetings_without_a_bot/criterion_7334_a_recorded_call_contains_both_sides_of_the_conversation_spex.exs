defmodule EarWitnessSpex.CaptureMyOwnMeetingsWithoutABot.Criterion7334Spex do
  @moduledoc """
  Story 861 — Capture my own meetings without a bot
  Criterion 7334: A recorded call contains both sides of the conversation

  "Both sides" is observable at the UI as the capture channels a recording
  carries: a tap capture records microphone (my voice) AND system audio
  (the remote side) into one recording. The fixture capture source feeds
  both channels from fixture audio; whether real Core Audio taps deliver
  remote audio is the Tier-2 integration concern (Audio context tests),
  not this spec's.
  """

  use EarWitnessSpex.Case

  spex "A recorded call contains both sides of the conversation" do
    scenario "meeting participant records a call through the tap", context do
      given_ "the tap is the active capture source", context do
        EarWitnessSpex.SettingsSteps.choose_tap_capture_source(context.conn)
        {:ok, view, _html} = live(context.conn, "/recordings")
        Map.put(context, :view, view)
      end

      when_ "they record while both they and the remote participant speak", context do
        context.view |> element("button", "Record") |> render_click()
        context.view |> element("button", "Stop") |> render_click()
        context
      end

      then_ "the recording carries both the microphone and system audio channels", context do
        assert has_element?(
                 context.view,
                 ~s([data-test="capture-channels"]),
                 "microphone + system audio"
               )

        :ok
      end

      then_ "it is one single recording in the library, not two", context do
        assert context.view
               |> render()
               |> then(&Regex.scan(~r/data-test="recording-row"/, &1))
               |> length() == 1

        :ok
      end
    end
  end
end
