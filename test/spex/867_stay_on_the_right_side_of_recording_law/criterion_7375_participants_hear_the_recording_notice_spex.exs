defmodule EarWitnessSpex.StayOnTheRightSideOfRecordingLaw.Criterion7375Spex do
  @moduledoc """
  Story 867 — Stay on the right side of recording law
  Criterion 7375: Participants hear the recording notice

  LiveViewTest cannot observe actual audio output, so this does not (and
  cannot) assert that a sound was literally played — that is the
  Audio.ConsentPolicy + Tap seam's integration concern. What it can
  assert is the UI/state contract the audible announcement gives us: the
  notice must be delivered before capture-status ever transitions to
  "recording". The clearest way to prove that gating relationship inside
  a synchronous LiveView test is to make delivery fail and show capture
  never reaches "recording" as a result — if delivery merely raced with
  recording instead of gating it, a failed delivery would not block
  capture. This reuses the existing failure seam,
  `EarWitnessSpex.Fixtures.simulate_announcement_delivery_failure/0` (the
  same one story 861's criterion 7337 and this story's criterion 7373
  exercise), rather than a new fixture.
  """

  use EarWitnessSpex.Case

  spex "Participants hear the recording notice" do
    scenario "the audible notice fails to deliver before capture would start", context do
      given_ "the announce policy is active", context do
        EarWitnessSpex.SettingsSteps.choose_consent_policy(context.conn, "announce")
        EarWitnessSpex.SettingsSteps.choose_tap_capture_source(context.conn)
        context
      end

      given_ "the audible recording notice cannot be delivered", context do
        EarWitnessSpex.Fixtures.simulate_announcement_delivery_failure()
        {:ok, view, _html} = live(context.conn, "/recordings")
        Map.put(context, :view, view)
      end

      when_ "they try to start a tap capture", context do
        html = context.view |> element("button", "Record") |> render_click()
        Map.put(context, :html, html)
      end

      then_ "the notice is reported as undelivered, not delivered", context do
        refute has_element?(
                 context.view,
                 ~s([data-test="announce-notice-status"]),
                 "delivered"
               )

        :ok
      end

      then_ "capture status never transitions to recording without the notice", context do
        refute has_element?(context.view, ~s([data-test="capture-status"]), "recording")
        :ok
      end
    end
  end
end
