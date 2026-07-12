defmodule EarWitnessSpex.SendABotToTheMeetingsICantAttend.Criterion7384Spex do
  @moduledoc """
  Story 869 — Send a bot to the meetings I can't attend
  Criterion 7384: The bot is visible to everyone in the meeting

  The claim under test is about what OTHER people, inside a real
  third-party meeting, see in that meeting's own participant list. No
  spec run from this app can read a remote meeting platform's UI or
  participant roster — there is no real Zoom/Meet/Teams call for the
  bot to join here. What this app CAN honestly assert is its own side of
  the contract: the bot session it dispatches carries a clearly
  identifying, visible display name — the name that would be sent to
  the meeting platform and therefore be what participants see. Whether
  that name genuinely renders correctly inside a real meeting's
  participant list is NOT provable from this suite; that verification
  belongs to manual QA against a real meeting (join a real call and look
  at the participant list) or a contract/integration test against the
  relay vendor's join API, run outside this BDD suite.

  Judgment calls made explicit (flag for a human to confirm before
  implementation):

  - The dispatch route/form/selector assumptions are those documented
    on `EarWitnessSpex.BotSteps`.
  - The bot's visible display name is assumed to be a fixed, non-
    configurable product identity (`"EarWitness Notetaker"`) rather
    than something the user types per dispatch — the story frames
    visibility as a transparency guarantee ("no stealth bot"), not a
    branding/customization feature, so this spec does not invent a
    `display_name` form field.
  """

  use EarWitnessSpex.Case

  spex "The bot is visible to everyone in the meeting" do
    scenario "busy professional dispatches a bot and can confirm it identifies itself openly",
             context do
      given_ "the bot dispatch page is open", context do
        {:ok, view, _html} = live(context.conn, "/bots")
        Map.put(context, :view, view)
      end

      when_ "they dispatch a bot to a meeting", context do
        html =
          context.view
          |> form(~s([data-test="bot-dispatch-form"]), %{
            "bot" => %{"meeting_url" => "https://zoom.us/j/5551234567"}
          })
          |> render_submit()

        [_, session_id] =
          Regex.run(~r/data-test="bot-session" data-session-id="([^"]+)"/, html)

        Map.put(context, :session_id, session_id)
      end

      then_ "the session shows the clearly identifying name the bot presents in the meeting " <>
              "— the closest in-app proxy for what participants would see",
            context do
        assert has_element?(
                 context.view,
                 ~s([data-test="bot-display-name"][data-session-id="#{context.session_id}"]),
                 "EarWitness Notetaker"
               )

        :ok
      end
    end
  end
end
