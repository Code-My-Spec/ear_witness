defmodule EarWitnessSpex.StayOnTheRightSideOfRecordingLaw.Criterion7371Spex do
  @moduledoc """
  Story 867 — Stay on the right side of recording law
  Criterion 7371: Pick the notify policy in settings

  Drives the choice through
  `EarWitnessSpex.SettingsSteps.choose_consent_policy/2` — the same helper
  story 861's criteria 7336-7338 use for consent-policy setup — rather
  than hand-rolling a parallel form-driving flow.

  Judgment call: starts from "silent" rather than whatever settings
  happens to default to, so the scenario proves a real change of policy
  took effect, not a match against a default it never touched (criterion
  7376 covers the fresh-install default itself). Asserts the chosen
  policy through a new `[data-test="active-consent-policy"]` element,
  mirroring the existing `[data-test="active-capture-source"]` convention
  for capture-source selection.
  """

  use EarWitnessSpex.Case

  spex "Pick the notify policy in settings" do
    scenario "meeting participant chooses the notify consent policy", context do
      given_ "the active consent policy is currently silent", context do
        EarWitnessSpex.SettingsSteps.choose_consent_policy(context.conn, "silent")
        context
      end

      when_ "they select the notify consent policy in settings", context do
        view = EarWitnessSpex.SettingsSteps.choose_consent_policy(context.conn, "notify")
        Map.put(context, :settings_view, view)
      end

      then_ "notify is shown as the active policy", context do
        assert has_element?(
                 context.settings_view,
                 ~s([data-test="active-consent-policy"]),
                 "notify"
               )

        :ok
      end

      then_ "the choice persists into a new session", context do
        fresh_conn = Phoenix.ConnTest.build_conn()
        {:ok, fresh_view, _html} = live(fresh_conn, "/settings")

        assert has_element?(
                 fresh_view,
                 ~s([data-test="active-consent-policy"]),
                 "notify"
               )

        :ok
      end
    end
  end
end
