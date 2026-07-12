# QA Story 869 Brief — Send a bot to the meetings I can't attend

## Tool

web (Vibium MCP browser tools — `EarWitnessWeb.BotLive`, route `/bots`,
`:browser` pipeline)

## Auth

Navigate once to the login URL for this session:
`http://localhost:4848/?k=P2MEKNUS2V6RE27ABCAQQDNZQ6W5VQ4SP5GTVBIMDDQCIZGXTHGA`
— sets the `Desktop.Auth` session cookie. Browse normally after that. If a
401 is hit, re-navigate to the same `/?k=...` URL (key does not rotate
mid-session, only per app boot).

## Seeds

None needed. `/bots` starts empty (`Bots.list_bot_sessions/0` on a fresh
DB) and every scenario below dispatches its own session live through the
real form. No `qa_seeds.exs` entries exist for bot sessions yet.

## Setup Notes

The relay seam (read before testing): the meeting-bot vendor is an
**unresolved ADR**
(`.code_my_spec/architecture/decisions/meeting-bot-relay.md`, status
"Proposed"). `EarWitness.Bots.Runner` joins meetings through a
config-selected seam (`config :ear_witness, :bot_relay`); the real app
(via `config/config.exs`) wires up `EarWitness.Bots.Runner.Relay`, whose
`join/1` unconditionally returns
`{:error, "Meeting bot dispatch isn't connected to a real meeting platform yet (see the meeting-bot-relay ADR)."}`
— immediately, with no delay. Consequence for this QA session:

- Every real dispatch through `/bots` will go `dispatched` -> `failed`
  almost instantly (a few ms), surfacing that exact reason in
  `[data-test="bot-failure-reason"]`. This is expected, honest-seam
  behavior per the ADR — **not** a bug to file.
- There is no real Zoom/Meet/Teams join, so criteria 7384 (visible in
  meeting), 7387 (recall mid-meeting), 7388 (waiting-room rejection
  specifically), 7389 (external retention), and the "automatic
  transcript" half of 7386 cannot be produced end-to-end by dispatching
  through the real UI — the BDD spex for those stage the precondition
  via `EarWitnessSpex.Fixtures.simulate_bot_*/1` test-double helpers
  that call `EarWitness.Bots.mark_recording/1`,
  `fail_bot_session/2`, `complete_bot_session/2` directly, bypassing the
  relay. This session tests everything observable through the real seam
  (dispatch, rename, the failure-reporting mechanism, UI contract) and
  clearly labels what is seam-backed vs. what would need a real relay
  vendor to observe end to end.
- `mix spex` (run separately, not through the browser) is the fastest way
  to confirm the seam-backed scenarios pass at the code level; the brief
  below still drives the real UI wherever the real seam allows it.

## What To Test

- **Criterion 7383 — Paste a meeting link and dispatch the bot.**
  Navigate to `/bots`. Confirm the empty state ("No bots dispatched
  yet."). Fill `[data-test="bot-dispatch-form"] input[name="bot[meeting_url]"]`
  with `https://zoom.us/j/5551234567` and submit. Expect a new
  `[data-test="bot-session"][data-session-id="..."]` row to appear
  immediately with that URL and status `dispatched` (via PubSub, no page
  reload) — capture a screenshot fast, since the honest-seam relay flips
  it to `failed` within milliseconds. A too-fast flip to `failed` before
  a screenshot lands is a real UX finding, not a test failure — note it.

- **Criterion 7396 — Rename the bot before dispatching it.** Reload
  `/bots`. Confirm `input[name="bot[display_name]"]` is pre-filled with
  the default `EarWitness Notetaker`. Clear it, type a custom name (e.g.
  `John's notetaker`), fill the meeting URL, submit. Expect the new
  session's `[data-test="bot-display-name"]` to show the custom name, not
  the default.

- **Criterion 7384 — The bot is visible to everyone in the meeting.**
  In-app proxy only (per the spex moduledoc: no real meeting to inspect
  a participant list against). Confirm the dispatched session's
  `[data-test="bot-display-name"]` renders the identifying name that
  would be sent to the meeting platform. Note in the brief/result that
  the "everyone in the meeting sees it" half of this claim is outside
  what this app or QA session can observe — seam-backed, not a defect.

- **Criterion 7385 — The meeting shows up in the library afterwards.**
  Real join/record/leave cannot be driven from the UI (no relay). Since
  browser QA cannot call `simulate_bot_join_completed/1` (that's an
  Elixir-only spex fixture, not exposed to the UI/API), this criterion's
  end-to-end path is **not reachable through the real running app this
  session** — note explicitly that it is verified at the BDD layer
  (`criterion_7385_..._spex.exs`) via the honest-seam fixture, not by
  this browser session. Still check `/recordings` for a
  `[data-test="recording-source"]` value of `"bot"` in case any prior
  session left one.

- **Criterion 7386 — Bot recordings get transcripts and speakers
  automatically.** Same reachability limit as 7385 — depends on a
  completed bot recording that only the spex fixture can stage. Note as
  spex-verified, not directly reachable via browser QA this session.

- **Criterion 7387 — Recall the bot mid-meeting.** Requires a session in
  `:dispatched` or `:recording` status long enough to click
  `[data-test="recall-button"]`. Attempt it live: dispatch a bot and
  race to click Recall before the seam's near-instant failure lands.
  Record whether the race is winnable in practice (screenshot either
  outcome). If unwinnable, that's an artifact of the honest-seam timing,
  not a recall-feature defect — the BDD spec
  (`criterion_7387_..._spex.exs`) exercises the real
  `[data-test="recall-button"]` control against a fixture-staged
  `:recording` session and is the authoritative verification of the
  recall mechanism itself.

- **Criterion 7388 — Waiting-room rejection is reported, not swallowed.**
  The specific "waiting room" wording is fixture-only
  (`simulate_bot_waiting_room_rejection/1`) and not reachable via the
  real UI this session. What **is** reachable and directly relevant:
  dispatch a real bot and confirm the resulting relay failure (not
  "connected to a real meeting platform yet") renders in
  `[data-test="bot-failure-reason"]` and the session stays visible in
  the list rather than disappearing — this is the same
  `fail_bot_session/2` code path a waiting-room rejection would use, so
  it's solid evidence the "not swallowed" mechanism works, short of the
  exact wording.

- **Criterion 7389 — External components never keep the conversation.**
  Per the spex moduledoc this is fundamentally a third-party vendor
  retention claim, not app-observable — no vendor is even selected yet
  (ADR "Proposed"). Nothing to test live this session beyond confirming
  no bot-related network egress happens on dispatch (the relay call is a
  local, synchronous, no-network stub — confirm by reading
  `lib/ear_witness/bots/runner/relay.ex`, already read during brief
  prep: `join/1` returns a hardcoded string, no HTTP call). Note as
  spex-verified (local-retention proxy) + code-read verified (no
  network call today), not live-browser verified.

- **General UI/contract checks (all criteria):** status badge colors,
  failure reason visibility only when `status == failed`, recall button
  only rendered for non-terminal sessions, multiple dispatches stack
  correctly in the list, blank meeting URL is rejected by the `required`
  HTML attribute (confirm whether there's also a server-side validation
  message for a submitted-empty case).

## Result Path

`.code_my_spec/qa/869/brief.md` (this file) — findings recorded as
issues via `create_issue`; DB attempt via `submit_qa_result`. Screenshots
in `.code_my_spec/qa/869/screenshots/`.
