defmodule EarWitnessSpex.SendABotToTheMeetingsICantAttend.Criterion7389Spex do
  @moduledoc """
  Story 869 — Send a bot to the meetings I can't attend
  Criterion 7389: External components never keep the conversation

  The claim under test is about a THIRD PARTY's backend behavior: the
  external relay service the bot runs behind must never retain the
  meeting's audio/data. No spec run from this app can inspect a
  vendor's servers, so the negative claim itself ("the relay keeps
  nothing") is NOT directly assertable here — that verification belongs
  to manual QA (e.g. inspecting the relay vendor's retention policy /
  API behavior against a real session) or a contract/integration test
  against the relay vendor's own attestations, run outside this BDD
  suite.

  What this spec pins instead is the honest in-app proxy available to
  it: once a bot session finishes, the full conversation — the audio
  recording AND its transcript — already lives in this app's own local
  library, independent of whatever the relay does or does not still
  hold. That local retention is complete is a necessary (if not
  sufficient) piece of the "local library, not the relay, is where the
  conversation lives" claim; it says nothing about what the relay
  itself does after handing the audio off.

  Judgment calls made explicit (flag for a human to confirm before
  implementation):

  - The dispatch route/form/selector assumptions are those documented
    on `EarWitnessSpex.BotSteps`; join/record/leave is staged with
    `EarWitnessSpex.Fixtures.simulate_bot_join_completed/1`, same as
    criterion 7385, since real join/record/leave cannot be driven from
    a spec.
  - `[data-test="recording-duration"]` presence is used as the proxy for
    "actual audio was retained" (not just an empty placeholder row) —
    the same selector story 860/criterion 7322 uses for that purpose.
  """

  use EarWitnessSpex.Case

  spex "External components never keep the conversation" do
    scenario "busy professional's meeting ends up fully preserved locally, not on a vendor's servers",
             context do
      given_ "a bot's meeting session has completed", context do
        {_view, _html, session_id} =
          EarWitnessSpex.BotSteps.dispatch_bot(context.conn, "https://zoom.us/j/5551234567")

        EarWitnessSpex.Fixtures.simulate_bot_join_completed(session_id)
        context
      end

      when_ "they open the resulting recording in the library", context do
        {:ok, recordings_view, recordings_html} = live(context.conn, "/recordings")
        [_, show_path] = Regex.run(~r{href="(/recordings/[^"]+)"}, recordings_html)
        {:ok, show_view, show_html} = live(context.conn, show_path)

        context
        |> Map.put(:recordings_view, recordings_view)
        |> Map.put(:show_view, show_view)
        |> Map.put(:show_html, show_html)
      end

      then_ "the full recording and its transcript already live in this app's local library " <>
              "— the only place this app claims to keep the conversation",
            context do
        assert has_element?(context.show_view, ~s([data-test="recording-duration"]))
        assert has_element?(context.show_view, ~s([data-test="transcript"]))

        :ok
      end
    end
  end
end
