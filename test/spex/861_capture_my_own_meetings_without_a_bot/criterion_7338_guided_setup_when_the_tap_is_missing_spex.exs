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
    scenario "meeting participant picks the tap on a machine where it is not set up", context do
      given_ "the tap device is not set up on this machine", context do
        EarWitnessSpex.Fixtures.simulate_tap_not_installed()
        context
      end

      when_ "they select the tap as a capture source", context do
        {:ok, view, _html} = live(context.conn, "/settings")

        html =
          view
          |> form(~s([data-test="capture-source-form"]), %{"source" => "tap"})
          |> render_change()

        context
        |> Map.put(:settings_view, view)
        |> Map.put(:html, html)
      end

      then_ "the app walks them through enabling it instead of failing silently", context do
        assert has_element?(context.settings_view, ~s([data-test="tap-setup-guide"]))
        :ok
      end

      then_ "the tap is not silently activated as the capture source", context do
        refute has_element?(
                 context.settings_view,
                 ~s([data-test="active-capture-source"]),
                 "tap"
               )

        :ok
      end
    end
  end
end
