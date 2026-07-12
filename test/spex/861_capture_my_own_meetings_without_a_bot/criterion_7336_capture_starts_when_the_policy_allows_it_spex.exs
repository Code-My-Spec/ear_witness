defmodule EarWitnessSpex.CaptureMyOwnMeetingsWithoutABot.Criterion7336Spex do
  @moduledoc """
  Story 861 — Capture my own meetings without a bot
  Criterion 7336: Capture starts when the policy allows it

  The consent policy is chosen through the real settings UI (never via
  `Application.put_env` — see the BDD plan's anti-patterns). "Silent" is
  the policy that permits capture with no further conditions, so it is the
  cleanest allows-it case.
  """

  use EarWitnessSpex.Case

  spex "Capture starts when the policy allows it" do
    scenario "meeting participant records under a policy that permits capture", context do
      given_ "the active consent policy permits capture in this situation", context do
        EarWitnessSpex.SettingsSteps.choose_consent_policy(context.conn, "silent")
        EarWitnessSpex.SettingsSteps.choose_tap_capture_source(context.conn)
        {:ok, view, _html} = live(context.conn, "/recordings")
        Map.put(context, :view, view)
      end

      when_ "they start a tap capture", context do
        html = context.view |> element("button", "Record") |> render_click()
        Map.put(context, :html, html)
      end

      then_ "recording begins", context do
        assert has_element?(context.view, ~s([data-test="capture-status"]), "recording")
        refute has_element?(context.view, ~s([data-test="capture-error"]))
        :ok
      end
    end
  end
end
