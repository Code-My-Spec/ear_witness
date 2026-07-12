defmodule EarWitnessSpex.StayOnTheRightSideOfRecordingLaw.Criterion7376Spex do
  @moduledoc """
  Story 867 — Stay on the right side of recording law
  Criterion 7376: Fresh install defaults to the protective policy

  "Protective" is the notify-by-default behavior the story description
  calls out explicitly ("recording without notifying participants is
  legal in some places and not others ... notify-by-default"): a fresh
  install must default to "notify", not "silent", so a new user cannot
  accidentally record without telling anyone before they have ever
  touched consent settings.

  Staged honestly: a brand-new `Plug.Conn` is built here rather than
  reused from another scenario, and
  `EarWitnessSpex.SettingsSteps.choose_consent_policy/2` is never called.
  The default is read off the rendered settings page itself
  (`[data-test="active-consent-policy"]`), never out of storage.

  Selector note: `[data-test="capture-notice"]` is the notify policy's
  own visible notification affordance shown when capture starts —
  distinct from `[data-test="announce-notice-status"]`, which reports
  delivery of the announce policy's audible notice (criteria 7372/7373/
  7375). It shows the default is not merely displayed but actually
  governs the first capture.
  """

  use EarWitnessSpex.Case

  spex "Fresh install defaults to the protective policy" do
    scenario "first capture on an untouched install is governed by notify", context do
      given_ "a brand-new session that has never touched consent settings", context do
        Map.put(context, :conn, Phoenix.ConnTest.build_conn())
      end

      when_ "they open settings for the first time", context do
        {:ok, settings_view, _html} = live(context.conn, "/settings")
        Map.put(context, :settings_view, settings_view)
      end

      and_ "they start their first capture without changing any setting", context do
        {:ok, recordings_view, _html} = live(context.conn, "/recordings")
        recordings_view |> element("button", "Record") |> render_click()
        Map.put(context, :recordings_view, recordings_view)
      end

      then_ "notify is the active policy without anyone choosing it", context do
        assert has_element?(
                 context.settings_view,
                 ~s([data-test="active-consent-policy"]),
                 "notify"
               )

        :ok
      end

      then_ "the first capture runs under the notify policy's behavior", context do
        assert has_element?(context.recordings_view, ~s([data-test="capture-notice"]))
        :ok
      end
    end
  end
end
