defmodule EarWitnessSpex.BotSteps do
  @moduledoc """
  Reusable steps for driving `EarWitnessWeb.BotLive` from BDD specs
  (story 869 — "Send a bot to the meetings I can't attend").

  Plain helper functions, not macros — same rationale as
  `EarWitnessSpex.RecordingSteps` (the installed `sexy_spex` (`~> 0.1.0`)
  has no shared-given registration mechanism, so specs call these
  directly from inside `given_`/`when_`/`then_` blocks). Every call here
  stays on the real LiveView surface — nothing here reaches into
  `EarWitness.*` contexts, `Repo`, `File`, or `Port` (see the local
  Credo check `EARWIT0001`).

  ## Route assumption

  `EarWitnessWeb.BotLive` is assumed reachable at `/bots`, per the
  project BDD plan's public-surfaces list
  (`.code_my_spec/knowledge/bdd/spex/index.md`) and the
  `[data-test="bot-session"]` selector already exercised from story 861
  (criterion 7335, which asserts the *absence* of a bot session after a
  tap capture).

  ## Selector contract (judgment calls made explicit — flag for a human
  before implementation)

  - `[data-test="bot-dispatch-form"]`, field `bot[meeting_url]` — pastes
    a meeting link and dispatches the bot immediately. The story
    description also mentions scheduling a bot in advance, but none of
    the seven acceptance criteria on this story (7383-7389) exercise a
    `schedule_at`-style field, so this helper only drives the
    immediate-dispatch path; a scheduling field is left undesigned here
    rather than invented — flag for a human: should scheduling get its
    own criterion/spec?
  - `[data-test="bot-session"][data-session-id="..."]` — one row per
    dispatched bot (selector established by story 861/criterion 7335;
    this module adds the `data-session-id` addressing convention,
    mirroring `data-segment-id` on `[data-test="transcript-segment"]`
    and `data-collection-id` on `[data-test="collection"]`).
  - `[data-test="bot-status"][data-session-id="..."]` — that session's
    current status text. Assumed vocabulary: `"dispatched"` (just
    created), `"recording"` (joined and actively capturing),
    `"completed"` (finished normally), `"recalled"` (pulled back by the
    user before finishing), `"failed"` (join never succeeded) — mirrors
    how `[data-test="capture-status"]`/`[data-test="download-status"]`
    carry prose status text elsewhere in this suite.
  - `[data-test="bot-display-name"][data-session-id="..."]` — the
    visible name the bot presents inside the meeting. The in-app proxy
    for "the bot is visible to everyone in the meeting" — no spec can
    read a real meeting's participant list (see criterion 7384's
    moduledoc for the full limitation).
  - `[data-test="recall-button"][data-session-id="..."]` — pulls the bot
    back out of the meeting before it would finish on its own.
  - `[data-test="bot-failure-reason"][data-session-id="..."]` — a
    human-readable reason shown when a session's join attempt fails,
    rather than the session silently disappearing.
  """

  @endpoint EarWitnessWeb.Endpoint

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @doc """
  Opens `/bots` and dispatches a bot to `meeting_url` through the real
  dispatch form (`[data-test="bot-dispatch-form"]`, field
  `bot[meeting_url]`). Returns `{view, html, session_id}` — the bots
  LiveView, its rendered HTML right after dispatch, and the new
  session's `data-session-id` (read off the resulting
  `[data-test="bot-session"]` row).
  """
  def dispatch_bot(conn, meeting_url) do
    {:ok, view, _html} = live(conn, "/bots")

    html =
      view
      |> form(~s([data-test="bot-dispatch-form"]), %{
        "bot" => %{"meeting_url" => meeting_url}
      })
      |> render_submit()

    [_, session_id] =
      Regex.run(~r/data-test="bot-session" data-session-id="([^"]+)"/, html)

    {view, html, session_id}
  end

  @doc """
  Clicks the recall control for the session identified by `session_id`
  (`[data-test="recall-button"][data-session-id="..."]`, story 869
  criterion 7387 — "Recall the bot mid-meeting"). Returns the rendered
  HTML after the click.
  """
  def recall_bot(view, session_id) do
    view
    |> element(~s([data-test="recall-button"][data-session-id="#{session_id}"]))
    |> render_click()
  end
end
