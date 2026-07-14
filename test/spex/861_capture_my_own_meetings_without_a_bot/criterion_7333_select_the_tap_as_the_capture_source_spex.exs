defmodule EarWitnessSpex.CaptureMyOwnMeetingsWithoutABot.Criterion7333Spex do
  @moduledoc """
  Story 861 — Capture my own meetings without a bot
  Criterion 7333: The system audio tap is captured automatically

  Reframed for the story-872 UAT decision: there is no capture-source picker
  anymore — every recording captures the microphone AND the system audio tap
  together (see `EarWitness.Audio.start_capture/1`). "Selecting the tap" is now
  automatic; settings just states what's captured, and a recording carries both
  channels. The tap device sits behind the `:capture_source` fixture seam (test
  env exposes a fixture tap); the flow is driven through the real UI.
  """

  use EarWitnessSpex.Case

  spex "The system audio tap is captured automatically" do
    scenario "meeting participant records without choosing a source", context do
      given_ "the tap device is available on this machine", context do
        # The :fixture capture source (config/test.exs) advertises a tap device.
        context
      end

      when_ "they open capture settings", context do
        {:ok, view, _html} = live(context.conn, "/settings")
        Map.put(context, :settings_view, view)
      end

      then_ "settings states the microphone and system audio are recorded together", context do
        assert has_element?(
                 context.settings_view,
                 ~s([data-test="capture-sources-summary"]),
                 "system audio"
               )

        :ok
      end

      then_ "the next capture records both without any source selection", context do
        {:ok, view, _html} = live(context.conn, "/recordings")
        view |> element("button", "Record") |> render_click()
        html = view |> element("button", "Stop") |> render_click()

        assert html =~ "microphone + system audio"
        :ok
      end
    end
  end
end
