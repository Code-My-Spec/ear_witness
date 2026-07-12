defmodule EarWitnessSpex.StayOnTheRightSideOfRecordingLaw.Criterion7374Spex do
  @moduledoc """
  Story 867 — Stay on the right side of recording law
  Criterion 7374: Policies are explained where they are chosen

  PM decision (Three Amigos 2026-07-11): generic plain-language
  explanations plus a not-legal-advice disclaimer — no jurisdiction
  database.

  Judgment call: introduces `[data-test="policy-option"]` (one per
  selectable policy, addressed by `data-policy="silent|notify|announce"`),
  `[data-test="policy-explanation"]` (same addressing, the plain-language
  text for that option), and a single `[data-test="legal-disclaimer"]`
  element. Starts from "silent" already active (via
  `EarWitnessSpex.SettingsSteps.choose_consent_policy/2`) so the scenario
  proves explanations render for every option on the page, not only for
  whichever policy happens to already be selected.
  """

  use EarWitnessSpex.Case

  spex "Policies are explained where they are chosen" do
    scenario "meeting participant reads what each policy means before choosing", context do
      given_ "the active consent policy is silent", context do
        EarWitnessSpex.SettingsSteps.choose_consent_policy(context.conn, "silent")
        context
      end

      when_ "they open settings to choose a consent policy", context do
        {:ok, view, _html} = live(context.conn, "/settings")
        Map.put(context, :view, view)
      end

      then_ "each of the three policies has a plain-language explanation", context do
        for policy <- ["silent", "notify", "announce"] do
          assert has_element?(
                   context.view,
                   ~s([data-test="policy-option"][data-policy="#{policy}"])
                 )

          assert has_element?(
                   context.view,
                   ~s([data-test="policy-explanation"][data-policy="#{policy}"])
                 )
        end

        :ok
      end

      then_ "a disclaimer states this is not legal advice", context do
        assert has_element?(context.view, ~s([data-test="legal-disclaimer"]))
        :ok
      end
    end
  end
end
