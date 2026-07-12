defmodule EarWitnessSpex.SendABotToTheMeetingsICantAttend.Criterion7385Spex do
  @moduledoc """
  Story 869 — Send a bot to the meetings I can't attend
  Criterion 7385: The meeting shows up in the library afterwards

  A bot actually joining, recording, and leaving a real meeting is not
  something any spec can drive — there is no real external meeting here
  — so the join-through-leave lifecycle is staged with
  `EarWitnessSpex.Fixtures.simulate_bot_join_completed/1`, the honestly-
  raising stub for the not-yet-implemented `EarWitness.Bots.Runner`
  seam. The dispatch itself still goes through the real
  `EarWitnessWeb.BotLive` form (`EarWitnessSpex.BotSteps.dispatch_bot/2`).

  Judgment calls made explicit (flag for a human to confirm before
  implementation):

  - The dispatch route/form/selector assumptions are those documented
    on `EarWitnessSpex.BotSteps`.
  - A bot-produced recording is assumed to report `"bot"` in
    `[data-test="recording-source"]` — a third value alongside
    `"captured"`/`"tap"` already asserted by stories 860/861 for
    tap-sourced recordings.
  - The library is re-opened with a fresh `live/2` mount after the
    fixture call (rather than reusing the bots-page view) so the
    assertion reads current DB-backed state instead of depending on
    exactly how/when an async completion event would reach an
    already-mounted view — mirrors how story 861/criterion 7335 opens a
    fresh `/bots` view to check cross-cutting state.
  """

  use EarWitnessSpex.Case

  spex "The meeting shows up in the library afterwards" do
    scenario "busy professional's bot brings the meeting home to the library once it's over",
             context do
      given_ "a bot has been dispatched to a meeting", context do
        {_view, _html, session_id} =
          EarWitnessSpex.BotSteps.dispatch_bot(context.conn, "https://zoom.us/j/5551234567")

        Map.put(context, :session_id, session_id)
      end

      when_ "the bot joins, records, and leaves the meeting", context do
        EarWitnessSpex.Fixtures.simulate_bot_join_completed(context.session_id)
        context
      end

      then_ "the resulting recording appears in the library, sourced from the bot", context do
        {:ok, recordings_view, _html} = live(context.conn, "/recordings")

        assert has_element?(recordings_view, ~s([data-test="recording-row"]))
        assert has_element?(recordings_view, ~s([data-test="recording-source"]), "bot")

        :ok
      end
    end
  end
end
