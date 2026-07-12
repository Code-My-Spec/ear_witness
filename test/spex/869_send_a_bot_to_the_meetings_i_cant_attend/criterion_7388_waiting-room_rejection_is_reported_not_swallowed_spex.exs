defmodule EarWitnessSpex.SendABotToTheMeetingsICantAttend.Criterion7388Spex do
  @moduledoc """
  Story 869 — Send a bot to the meetings I can't attend
  Criterion 7388: Waiting-room rejection is reported, not swallowed

  A real host declining to admit the bot from a meeting's waiting room
  is not something any spec can drive — there is no real external
  meeting here — so that join failure is staged with
  `EarWitnessSpex.Fixtures.simulate_bot_waiting_room_rejection/1`, the
  honestly-raising stub for the not-yet-implemented
  `EarWitness.Bots.Runner` seam. "Not swallowed" is read as two
  distinct, checkable claims: the session stays visible (it doesn't
  just vanish from the list), and its status/reason name what actually
  went wrong rather than a generic failure.

  Judgment calls made explicit (flag for a human to confirm before
  implementation):

  - The dispatch/status/failure-reason selector assumptions are those
    documented on `EarWitnessSpex.BotSteps`.
  - A rejected session's status is assumed to render as `"failed"` in
    `[data-test="bot-status"]`.
  - The failure reason is assumed to mention `"waiting room"` in
    `[data-test="bot-failure-reason"]` — specific enough to distinguish
    a waiting-room rejection from other join failures (e.g. an invalid
    link), which is the essence of "reported," not just "errored."
  - The bots page is re-mounted fresh (`live/2`) after the fixture call
    before reading status, for the same reason criterion 7385/7387
    remount rather than reuse the dispatch-time view.
  """

  use EarWitnessSpex.Case

  spex "Waiting-room rejection is reported, not swallowed" do
    scenario "busy professional's bot is turned away at the door and they're told why",
             context do
      given_ "a bot has been dispatched to a meeting", context do
        {_view, _html, session_id} =
          EarWitnessSpex.BotSteps.dispatch_bot(context.conn, "https://zoom.us/j/5551234567")

        Map.put(context, :session_id, session_id)
      end

      when_ "the meeting's waiting room rejects the bot's join attempt", context do
        EarWitnessSpex.Fixtures.simulate_bot_waiting_room_rejection(context.session_id)
        {:ok, view, _html} = live(context.conn, "/bots")
        Map.put(context, :view, view)
      end

      then_ "the session is reported as failed rather than silently dropped from the list",
            context do
        assert has_element?(
                 context.view,
                 ~s([data-test="bot-session"][data-session-id="#{context.session_id}"])
               )

        assert has_element?(
                 context.view,
                 ~s([data-test="bot-status"][data-session-id="#{context.session_id}"]),
                 "failed"
               )

        :ok
      end

      then_ "the failure reason names the waiting-room rejection, not a generic error",
            context do
        assert has_element?(
                 context.view,
                 ~s([data-test="bot-failure-reason"][data-session-id="#{context.session_id}"]),
                 "waiting room"
               )

        :ok
      end
    end
  end
end
