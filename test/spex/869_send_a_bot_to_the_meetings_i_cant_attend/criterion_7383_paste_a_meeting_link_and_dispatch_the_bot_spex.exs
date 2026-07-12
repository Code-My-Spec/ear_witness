defmodule EarWitnessSpex.SendABotToTheMeetingsICantAttend.Criterion7383Spex do
  @moduledoc """
  Story 869 — Send a bot to the meetings I can't attend
  Criterion 7383: Paste a meeting link and dispatch the bot

  The literal action the criterion names: paste a meeting link into the
  dispatch form and dispatch a bot to it. This spec drives that action
  inline (rather than through `EarWitnessSpex.BotSteps.dispatch_bot/2`)
  since it IS the canonical definition of dispatching — other criteria's
  specs reuse the shared helper for their setup, mirroring how story
  860's `RecordingSteps.import_wav/3` is defined by criterion 7322 but
  reused (not redefined) by later criteria.

  Judgment calls made explicit (flag for a human to confirm before
  implementation — see `EarWitnessSpex.BotSteps` for the full selector
  contract):

  - The dispatch route/form/selector assumptions are those documented
    on `EarWitnessSpex.BotSteps`.
  - The story also describes scheduling a bot in advance ("either
    immediately or scheduled in advance"), but none of the seven
    acceptance criteria on this story exercise a scheduling field, so
    this spec — and every other 869 spec — covers only the immediate
    dispatch path. Whether scheduling needs its own criterion is an
    open question for a human, not something this spec invents an
    answer to.
  - A freshly dispatched session's status is assumed to render as
    `"dispatched"` in `[data-test="bot-status"]`.
  """

  use EarWitnessSpex.Case

  spex "Paste a meeting link and dispatch the bot" do
    scenario "busy professional pastes a meeting link so a bot attends in their place",
             context do
      given_ "the bot dispatch page is open", context do
        {:ok, view, _html} = live(context.conn, "/bots")
        Map.put(context, :view, view)
      end

      when_ "they paste a meeting link and dispatch the bot", context do
        html =
          context.view
          |> form(~s([data-test="bot-dispatch-form"]), %{
            "bot" => %{"meeting_url" => "https://zoom.us/j/5551234567"}
          })
          |> render_submit()

        [_, session_id] =
          Regex.run(~r/data-test="bot-session" data-session-id="([^"]+)"/, html)

        context
        |> Map.put(:html, html)
        |> Map.put(:session_id, session_id)
      end

      then_ "a new bot session is dispatched to that specific meeting", context do
        assert has_element?(
                 context.view,
                 ~s([data-test="bot-session"][data-session-id="#{context.session_id}"]),
                 "https://zoom.us/j/5551234567"
               )

        :ok
      end

      then_ "the session's status shows it as dispatched, not idle or failed", context do
        assert has_element?(
                 context.view,
                 ~s([data-test="bot-status"][data-session-id="#{context.session_id}"]),
                 "dispatched"
               )

        :ok
      end
    end
  end
end
