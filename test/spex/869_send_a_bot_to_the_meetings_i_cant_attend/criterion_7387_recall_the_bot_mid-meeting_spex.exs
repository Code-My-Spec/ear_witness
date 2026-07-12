defmodule EarWitnessSpex.SendABotToTheMeetingsICantAttend.Criterion7387Spex do
  @moduledoc """
  Story 869 — Send a bot to the meetings I can't attend
  Criterion 7387: Recall the bot mid-meeting

  "Mid-meeting" means the bot has already joined and is actively
  recording, with the meeting still underway — a state no spec can
  drive by actually joining a real meeting. That precondition is staged
  with `EarWitnessSpex.Fixtures.simulate_bot_actively_recording/1`, the
  honestly-raising stub for the not-yet-implemented
  `EarWitness.Bots.Runner` seam. The recall action itself
  (`EarWitnessSpex.BotSteps.recall_bot/2`) drives the real
  `[data-test="recall-button"]` control.

  Judgment calls made explicit (flag for a human to confirm before
  implementation):

  - The dispatch/status/recall selector assumptions are those
    documented on `EarWitnessSpex.BotSteps`.
  - A recalled session's status is assumed to render as `"recalled"` in
    `[data-test="bot-status"]`, distinct from `"completed"` (finished on
    its own) or `"failed"` (never joined).
  - Once recalled, `[data-test="recall-button"]` is assumed to stop
    being offered for that session (nothing left to pull back) —
    mirrors how `[data-test="model-option"]`/`[data-test="transcribe-
    button"]` disappear once their action no longer applies elsewhere
    in this suite.
  - The bots page is re-mounted fresh (`live/2`) after
    `simulate_bot_actively_recording/1` before the recall click, rather
    than reusing the view from dispatch, so the click lands on
    current DB-backed state — same rationale as criterion 7385's fresh
    remount.
  """

  use EarWitnessSpex.Case

  spex "Recall the bot mid-meeting" do
    scenario "busy professional pulls their bot back out of a meeting before it ends",
             context do
      given_ "a bot has joined a meeting and is actively recording, meeting still underway",
             context do
        {_view, _html, session_id} =
          EarWitnessSpex.BotSteps.dispatch_bot(context.conn, "https://zoom.us/j/5551234567")

        EarWitnessSpex.Fixtures.simulate_bot_actively_recording(session_id)

        {:ok, view, _html} = live(context.conn, "/bots")

        context
        |> Map.put(:view, view)
        |> Map.put(:session_id, session_id)
      end

      when_ "they recall the bot before it would finish on its own", context do
        html = EarWitnessSpex.BotSteps.recall_bot(context.view, context.session_id)
        Map.put(context, :html, html)
      end

      then_ "the session shows it was recalled rather than continuing to record", context do
        assert has_element?(
                 context.view,
                 ~s([data-test="bot-status"][data-session-id="#{context.session_id}"]),
                 "recalled"
               )

        :ok
      end

      then_ "the recall control is no longer offered for a session that already left", context do
        refute has_element?(
                 context.view,
                 ~s([data-test="recall-button"][data-session-id="#{context.session_id}"])
               )

        :ok
      end
    end
  end
end
