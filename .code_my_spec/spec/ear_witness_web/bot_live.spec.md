# EarWitnessWeb.BotLive

Dispatch and monitor meeting bots — paste a meeting link and dispatch a bot immediately, watch each session's status update live, recall a bot mid-meeting, and jump to the resulting recording once it lands in the library.

## Type

liveview

## Route

`/bots`

## User Interactions

- **phx-submit="dispatch"** (form `[data-test="bot-dispatch-form"]`, field `bot[meeting_url]`): validate the pasted meeting link and call `EarWitness.Bots.dispatch_bot/1` with `%{"meeting_url" => meeting_url}`. On success the new session appears immediately in the session list (`[data-test="bot-session"][data-session-id="..."]`) at status `"dispatched"`, delivered live via `EarWitness.Bots.subscribe/0`/PubSub rather than a page reload. On `{:error, changeset}` (e.g. a blank meeting link) show the validation error inline and leave the pasted value in the field.
- **phx-click="recall"** (button `[data-test="recall-button"][data-session-id="..."]`, rendered only for a session whose status is not yet terminal): call `EarWitness.Bots.recall_bot/1` with the session id. The row's status updates to `"recalled"` and the recall button stops rendering for that row.
- **phx-click="view_recording"** (link shown on a session's row only once it has a linked recording): navigate to `EarWitnessWeb.RecordingLive.Show` (route `/recordings/:id`) via `<.link navigate={...}>` — pure navigation, no context call.

## Dependencies

- EarWitness.Bots

## Design

Layout: single-column page — a dispatch card above a live-updating list of sessions.

- Card: dispatch form — a single `.input`/`.form-control` text field for `bot[meeting_url]` and a `.btn-primary` submit button.
- Table on wider viewports, collapsing to a stacked `.card` list below the `sm` breakpoint (mirrors `RecordingLive.Index`): one row per dispatched session (`[data-test="bot-session"][data-session-id="..."]`), each showing:
  - the meeting URL and the bot's visible display name (`[data-test="bot-display-name"]`) — the in-app proxy for "the bot is visible to everyone in the meeting"; a remote meeting's actual participant list is outside what this app or its specs can observe (see the story 869 BDD spec moduledocs for that limitation and where it's actually verified)
  - a `.badge` status indicator (`[data-test="bot-status"]`), colored by state: neutral for `dispatched`, `.badge-info` for `recording`, `.badge-success` for `completed`, `.badge-warning` for `recalled`, `.badge-error` for `failed`
  - the failure reason (`[data-test="bot-failure-reason"]`), rendered only when status is `failed`
  - a `.btn-outline`/`.btn-error` recall button (`[data-test="recall-button"]`), rendered only for a non-terminal session
  - a link to the resulting recording, rendered only once `recording_id` is set
- Real-time: the list re-renders as status changes arrive over PubSub (`EarWitness.Bots.subscribe/0`) — dispatch, recording, completion, recall, and failure all show up without the user refreshing.

## Params

None

## Components

None — kept as a single flat LiveView per the project's "keep liveviews small and focused" rule. The session list has no independent interaction surface of its own, so it's rendered inline rather than factored into a child function component.
