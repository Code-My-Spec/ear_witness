defmodule EarWitnessSpex.StayOnTheRightSideOfRecordingLaw.Criterion7372Spex do
  @moduledoc """
  Story 867 — Stay on the right side of recording law
  Criterion 7372: Capture proceeds only on the policy's terms

  "Silent" already proceeds with no further condition (story 861,
  criterion 7336) and "notify"/"announce" selection is covered by
  criteria 7371/7376/7374, so the case worth pinning here is "announce":
  recording may proceed once the audible notice reports delivered, not
  unconditionally. Actual audio delivery is the ConsentPolicy/Tap seam's
  integration concern (see criterion 7375's moduledoc for that
  observability limit); this asserts the UI/state contract the app must
  expose — the notice status and the capture status agreeing with each
  other.

  Consent policy and capture source are driven through the real settings
  UI via `EarWitnessSpex.SettingsSteps`, never `Application.put_env`.
  """

  use EarWitnessSpex.Case

  spex "Capture proceeds only on the policy's terms" do
    scenario "meeting participant records under the announce policy", context do
      given_ "the announce policy is active", context do
        EarWitnessSpex.SettingsSteps.choose_consent_policy(context.conn, "announce")
        EarWitnessSpex.SettingsSteps.choose_tap_capture_source(context.conn)
        {:ok, view, _html} = live(context.conn, "/recordings")
        Map.put(context, :view, view)
      end

      when_ "they start a tap capture", context do
        html = context.view |> element("button", "Record") |> render_click()
        Map.put(context, :html, html)
      end

      then_ "the announcement is reported delivered", context do
        assert has_element?(
                 context.view,
                 ~s([data-test="announce-notice-status"]),
                 "delivered"
               )

        :ok
      end

      then_ "recording proceeds now that the policy's terms are met", context do
        assert has_element?(context.view, ~s([data-test="capture-status"]), "recording")
        refute has_element?(context.view, ~s([data-test="capture-error"]))
        :ok
      end
    end
  end
end
