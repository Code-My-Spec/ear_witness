defmodule EarWitnessSpex.CaptureMyOwnMeetingsWithoutABot.Criterion7338Spex do
  @moduledoc """
  Story 861 — Capture my own meetings without a bot
  Criterion 7338: Guided setup when the tap is missing

  Tap absence sits behind the Audio.Tap seam
  (`EarWitnessSpex.Fixtures.simulate_tap_not_installed/0`); the guided
  setup flow is asserted through the real settings UI.
  """

  use EarWitnessSpex.Case

  spex "Guided setup when the tap is missing" do
    scenario "meeting participant opens settings on a machine where the tap is not set up",
             context do
      given_ "the tap device is not set up on this machine", context do
        EarWitnessSpex.Fixtures.simulate_tap_not_installed()
        context
      end

      when_ "they open capture settings", context do
        {:ok, view, _html} = live(context.conn, "/settings")
        Map.put(context, :settings_view, view)
      end

      then_ "the app walks them through enabling it instead of failing silently", context do
        assert has_element?(context.settings_view, ~s([data-test="tap-setup-guide"]))
        :ok
      end

      then_ "it is clear the tap is not active — recordings are microphone-only until set up",
            context do
        assert has_element?(context.settings_view, ~s([data-test="tap-setup-guide"]), "microphone only")
        :ok
      end
    end
  end
end
