defmodule EarWitnessSpex.CaptureMyOwnMeetingsWithoutABot.Criterion7333Spex do
  @moduledoc """
  Story 861 — Capture my own meetings without a bot
  Criterion 7333: Select the tap as the capture source

  The tap device itself sits behind the `:capture_source` fixture seam
  (test env exposes a fixture tap device — no real Core Audio tap on CI);
  the selection flow is driven entirely through the real settings and
  recording UI.
  """

  use EarWitnessSpex.Case

  spex "Select the tap as the capture source" do
    scenario "meeting participant switches capture to the system audio tap", context do
      given_ "the tap device is available on this machine", context do
        # The :fixture capture source (config/test.exs) advertises a tap
        # device; availability is the seam, the selection below is real UI.
        context
      end

      when_ "they select the system audio tap in capture settings", context do
        view = EarWitnessSpex.SettingsSteps.choose_tap_capture_source(context.conn)
        Map.put(context, :settings_view, view)
      end

      then_ "the tap is shown as the active capture source", context do
        assert has_element?(
                 context.settings_view,
                 ~s([data-test="active-capture-source"]),
                 "tap"
               )

        :ok
      end

      then_ "the next capture uses the tap as its source", context do
        {:ok, view, _html} = live(context.conn, "/recordings")
        view |> element("button", "Record") |> render_click()
        view |> element("button", "Stop") |> render_click()

        assert has_element?(view, ~s([data-test="recording-source"]), "tap")
        :ok
      end
    end
  end
end
