defmodule EarWitnessSpex.CaptureMyOwnMeetingsWithoutABot.Criterion7337Spex do
  @moduledoc """
  Story 861 — Capture my own meetings without a bot
  Criterion 7337: Capture refused when the policy's conditions are unmet

  The announce policy's condition is that the audible notice is delivered
  before any audio is kept. Delivery failure sits behind the ConsentPolicy
  seam (`EarWitnessSpex.Fixtures.simulate_announcement_delivery_failure/0`)
  — the refusal behavior itself is asserted through the real UI: refused
  with an explanation, and no recording kept.
  """

  use EarWitnessSpex.Case

  spex "Capture refused when the policy's conditions are unmet" do
    scenario "meeting participant tries to capture but the required notice cannot be delivered",
             context do
      given_ "the announce policy is active", context do
        EarWitnessSpex.SettingsSteps.choose_consent_policy(context.conn, "announce")
        EarWitnessSpex.SettingsSteps.choose_tap_capture_source(context.conn)
        context
      end

      given_ "the recording notice cannot be delivered", context do
        EarWitnessSpex.Fixtures.simulate_announcement_delivery_failure()
        {:ok, view, _html} = live(context.conn, "/recordings")
        Map.put(context, :view, view)
      end

      when_ "they try to start a tap capture", context do
        html = context.view |> element("button", "Record") |> render_click()
        Map.put(context, :html, html)
      end

      then_ "the capture is refused with an explanation of what the policy requires", context do
        assert has_element?(context.view, ~s([data-test="capture-error"]))
        assert context.html =~ "announce"
        :ok
      end

      then_ "no audio was kept", context do
        refute has_element?(context.view, ~s([data-test="recording-row"]))
        refute has_element?(context.view, ~s([data-test="capture-status"]), "recording")
        :ok
      end
    end
  end
end
