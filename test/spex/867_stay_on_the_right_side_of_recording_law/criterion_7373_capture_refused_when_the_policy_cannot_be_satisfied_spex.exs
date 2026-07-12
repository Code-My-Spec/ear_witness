defmodule EarWitnessSpex.StayOnTheRightSideOfRecordingLaw.Criterion7373Spex do
  @moduledoc """
  Story 867 — Stay on the right side of recording law
  Criterion 7373: Capture refused when the policy cannot be satisfied

  The only policy with a real, seeded deliverability failure today is
  "announce" — its required audible notice can fail to deliver via
  `EarWitnessSpex.Fixtures.simulate_announcement_delivery_failure/0` (the
  same seam story 861's criterion 7337 exercises). This restates that
  same general "refused when the policy's terms can't be met" contract as
  its own story-867 acceptance criterion. The load-bearing assertion:
  refusal, with an explanation, and no audio kept — never a silent
  fallback to recording anyway.
  """

  use EarWitnessSpex.Case

  spex "Capture refused when the policy cannot be satisfied" do
    scenario "the required notice cannot be delivered", context do
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

      then_ "the capture is refused with an explanation instead of recording silently",
            context do
        assert has_element?(context.view, ~s([data-test="capture-error"]))
        refute has_element?(context.view, ~s([data-test="capture-status"]), "recording")
        refute has_element?(context.view, ~s([data-test="recording-row"]))
        :ok
      end
    end
  end
end
