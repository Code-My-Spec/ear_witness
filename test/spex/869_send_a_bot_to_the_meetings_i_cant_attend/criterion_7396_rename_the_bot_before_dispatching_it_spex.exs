defmodule EarWitnessSpex.SendABotToTheMeetingsICantAttend.Criterion7396Spex do
  @moduledoc """
  Story 869 — Send a bot to the meetings I can't attend
  Criterion 7396: Rename the bot before dispatching it

  PM decision (red-card resolution 2026-07-11): display name is
  configurable per dispatch, defaulting to "EarWitness Notetaker". The
  dispatch form gains a `bot[display_name]` field alongside
  `bot[meeting_url]`; the session's visible name is asserted through the
  existing `[data-test="bot-display-name"]` selector. As with the rest of
  story 869, what the remote meeting literally shows is manual-QA
  territory — this pins the app-side contract.
  """

  use EarWitnessSpex.Case

  spex "Rename the bot before dispatching it" do
    scenario "busy professional sends the bot under a personal name", context do
      given_ "the dispatch form shows the default display name", context do
        {:ok, view, _html} = live(context.conn, "/bots")

        assert has_element?(
                 context_view = view,
                 ~s([data-test="bot-dispatch-form"] [name="bot[display_name]"][value="EarWitness Notetaker"])
               )

        Map.put(context, :view, context_view)
      end

      when_ "they set the display name and dispatch the bot", context do
        html =
          context.view
          |> form(~s([data-test="bot-dispatch-form"]), %{
            "bot" => %{
              "meeting_url" => "https://zoom.us/j/123456789",
              "display_name" => "John's notetaker"
            }
          })
          |> render_submit()

        Map.put(context, :html, html)
      end

      then_ "the bot session shows it joined as the chosen name", context do
        assert has_element?(
                 context.view,
                 ~s([data-test="bot-display-name"]),
                 "John's notetaker"
               )

        :ok
      end
    end
  end
end
