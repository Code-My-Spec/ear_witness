# Qa Story Brief — 861 Capture my own meetings without a bot

## Tool

web (Vibium MCP browser tools) for all scenarios — `/settings`, `/recordings`, `/bots` are
all LiveViews on the `:browser` pipeline. No `:api` routes exist for this story.

## Auth

Desktop.Auth guards every route with a per-boot login key. Navigate the browser to the
login URL once at the start of the session — it sets a session cookie the browser reuses
for every subsequent navigation:

    http://localhost:4848/?k=X3HKQM7YH6KXWU5O2622ZENTCHERWJFKDABHUCVGXX6E53LA66CA

If curl checks are needed (route reachability / 401 probes only — never for the LiveView
scenarios below), use:

    .code_my_spec/qa/scripts/qa_login.sh X3HKQM7YH6KXWU5O2622ZENTCHERWJFKDABHUCVGXX6E53LA66CA
    .code_my_spec/qa/scripts/authenticated_curl.sh /path

If the key ever 401s (a restart rotated it), stop and ask for a fresh key rather than
improvising.

## Seeds

No story-specific seeds required. This is a live, stateful desktop instance (not a fresh
`mix test` sandbox) — Settings is a singleton row that persists across the session, and
recordings created during this QA pass land permanently in the library. No seed script run
needed; `EarWitness.Audio` settings default from whatever the box was left at.

## What To Test

Reality check first (per ADR `membrane-audio-capture` / `EarWitness.Audio.Tap`): the real
system-audio-tap (Core Audio/WASAPI) is **not implemented**. `Tap.installed?` is `false` on
a real machine, and `Pipeline.start_real(:system_audio_tap, _)` always returns
`{:error, :source_unavailable}`. The `:fixture` seam used by the spex files is test-only.
On the real app, tap unavailability is EXPECTED behavior to verify honestly, not a bug to
file. Real capture uses the microphone path.

- **Settings page loads and shows capture source options** (`GET /settings`): both
  Microphone and System Audio Tap appear in `[data-test="capture-source-form"]`; the tap
  option carries a "not set up" badge since `Tap.installed?` is false on this machine.
  Maps to: select the tap as the capture source (honesty half) + guided setup when the tap
  is missing.

- **Selecting the tap on this machine triggers guided setup, not silent failure or a
  silent switch**: pick the "System Audio Tap" radio in the capture-source form. Expect
  `[data-test="tap-setup-guide"]` alert to render, and `[data-test="active-capture-source"]`
  to remain "microphone" (the switch must be refused, not silently accepted). Maps to:
  guided setup when the tap is missing.

- **Consent policy selection persists and is visible**: in `[data-test="consent-policy-form"]`,
  select each of silent / notify / announce in turn. After each selection,
  `[data-test="active-consent-policy"]` must reflect the new choice, and a fresh page load
  of `/settings` must still show the same choice (proves it's persisted, not just local
  LiveView state). Maps to: capture starts when the policy allows it (policy selection half).

- **Microphone capture records and lands in the library with a valid WAV** (the real,
  working path — story-860's WAV-header bug is the regression guard here): ensure capture
  source is set to Microphone in Settings, then on `/recordings` click Record, wait ~2s,
  click Stop. Expect `[data-test="capture-status"]` to show "recording" while active, no
  `[data-test="capture-error"]`, and after Stop a new `[data-test="recording-row"]` in
  Uncategorized with a non-zero `[data-test="recording-duration"]` and
  `[data-test="recording-source"]` badge of "captured" (mic path, not "tap"). Maps to: a
  recorded call contains both sides is NOT achievable with mic-only (only tap gives both
  sides) — note this as an ADR-documented limitation, not a bug; verify the mic path itself
  works cleanly instead (regression coverage for the WAV bug).

- **No bot joins on a plain capture**: after the mic record/stop above, navigate to `/bots`
  and confirm no `[data-test="bot-session"]` element was created by that capture. Maps to:
  nothing joins the meeting when capture runs.

- **Consent policy governs real capture (positive path)**: with policy set to "announce"
  and source set to Microphone, click Record. Since real announce-delivery has no failure
  seam outside tests, delivery always succeeds — expect capture to start normally
  (`[data-test="capture-status"]` = recording, no error) and, per the component,
  `[data-test="announce-notice-status"]` = "delivered" once stopped/observed. This is the
  closest real-environment analog to "capture starts when the policy allows it"; the
  delivery-failure refusal path (criterion 7337) is a test-only seam
  (`simulate_announcement_delivery_failure/0`) and cannot be reproduced on this machine —
  note as expected, not a gap.

- **Refusal analog for unmet conditions**: attempt to actually run a tap capture (not just
  select it) while it's unavailable — e.g. via repeated selection attempts or confirming the
  Record button behavior if tap were forced active. If reachable through the UI, expect a
  clear `[data-test="capture-error"]` explanation, never a silent no-op. This exercises the
  same refusal contract as criterion 7337 but through the source-unavailable branch instead
  of notice-undelivered.

- **Explore freely**: check `/settings` visually (screenshot), confirm the legal disclaimer
  text renders under the consent policy section, and confirm switching consent policy
  mid-session doesn't require a page reload to take effect.

## Result Path

Findings are filed via `create_issue` as discovered (see workflow). Final call is
`submit_qa_result` with `task_id: 3c0a6a78-a4e0-4bf5-8fab-a8939304887b`. Screenshots saved
to `.code_my_spec/qa/861/screenshots/`.

## Setup Notes

This is a stable, already-running desktop instance shared with other QA work (story 860
covered import/library/trash flows already) — avoid deleting collections or recordings that
aren't clearly QA861-prefixed. Prefix any collection/recording names created during this
pass with "QA861-" so they're identifiable and safe to clean up later. The desktop window
is real (not headless) — this is expected for an elixir-desktop app.
