# QA Brief — Story 867: Stay on the right side of recording law

## Tool

web

## Auth

The app is already running at `http://localhost:4848` (desktop QA server —
do not start/stop it). Navigate the vibium browser ONCE to:

    http://localhost:4848/?k=LNBADTLQDLWWDIJKG5X326OPQFFH6PQG2XWIT44YTK3DDG764J4Q

This sets the `Desktop.Auth` session cookie. After that, navigate normally
with plain URLs (`/settings`, `/recordings`, etc). If a 401 is ever hit,
re-navigate to the `/?k=...` URL to refresh the session (see
`.code_my_spec/qa/plan.md` System Issues — the key rotates per boot, but this
QA server's key is fixed for the session per the task prompt).

## Seeds

No seed script needed for this story — consent policy and capture source are
both persisted in the singleton `audio_settings` row and are set entirely
through the Settings UI itself (`EarWitness.Audio.set_consent_policy/1`,
`EarWitness.Audio.set_active_capture_source/1`). No fixtures required to
exercise the "silent"/"notify" happy paths.

Known environment constraint (confirmed by reading `lib/ear_witness/audio/tap.ex`
and `lib/ear_witness/audio/consent_policy.ex`):

- This QA box is macOS. `EarWitness.Audio.Tap.installed?/0` calls
  `Miniaudio.loopback_available?/0`, which has no macOS backend — so the
  **System Audio Tap capture source will show "not set up" and cannot be
  selected** on this machine. Capture testing must use the **Microphone**
  source instead. The consent-policy gate in `EarWitness.Audio.start_capture/1`
  is independent of capture source (`ConsentPolicy.authorize/1` runs before
  `Pipeline.capture/2`), so policy behavior (silent/notify/announce) can be
  fully exercised via the microphone source.
- `EarWitness.Audio.ConsentPolicy.authorize(:announce)` only returns
  `{:error, :notice_undelivered}` when
  `Application.get_env(:ear_witness, :announcement_delivery_override) == :fail`
  — a test-only fixture seam (`EarWitnessSpex.Fixtures.simulate_announcement_delivery_failure/0`).
  There is no config override or UI affordance to trigger this in the running
  dev/QA app, and no real audible-notice playback is wired up anywhere in
  `lib/` (confirmed: no play/beep/tts/speak code exists). So criteria 7373 and
  7375's "refused" / "notice fails to deliver" paths are **not reachable
  through the live UI** on this build — real delivery "succeeds unconditionally
  outside the test seam" per the module's own doc comment. Test what the real
  app actually does (announce always reports "delivered" and capture always
  proceeds), and record this observability gap rather than fabricating a
  failure path.

## What To Test

All against `EarWitnessWeb.SettingsLive` (`/settings`) and
`EarWitnessWeb.RecordingLive.Index` (`/recordings`).

- **Criterion 7371 — Pick the notify policy in settings**
  - Navigate to `/settings`. Confirm the "Recording consent policy" card
    shows an `active-consent-policy` value and three radio options
    (`policy-option` with `data-policy="silent|notify|announce"`).
  - Select "notify" (click its radio). Confirm
    `[data-test="active-consent-policy"]` updates to show `notify`.
  - Reload `/settings` (fresh page load = fresh LiveView mount = "new
    session" proxy). Confirm the policy is still `notify` (persisted).

- **Criterion 7372 — Capture proceeds only on the policy's terms**
  - On `/settings`, select capture source = Microphone (radio in "Capture
    source" card) and consent policy = "announce".
  - Navigate to `/recordings`. Click "Record". Confirm
    `[data-test="announce-notice-status"]` shows "delivered" and
    `[data-test="capture-status"]` shows "recording", with no
    `[data-test="capture-error"]`. Click "Stop" to end the capture cleanly.

- **Criterion 7373 — Capture refused when the policy cannot be satisfied**
  - Per the Seeds section above, there is no live-app trigger for a failed
    announce delivery — the fixture seam
    (`simulate_announcement_delivery_failure/0`) only exists in the spex
    test environment. Document this as a `PARTIAL` finding: verify (from
    source review of `handle_record/1` in `recording_live/index.ex`) that
    an `{:error, :notice_undelivered}` result IS wired to set
    `capture_error` and `capturing?: false` — the code path exists — but it
    cannot be triggered live. Also test the adjacent real failure path that
    IS reachable live: select "System Audio Tap" as capture source (it will
    show "not set up") and confirm the UI explains the tap isn't available
    rather than silently failing.

- **Criterion 7374 — Policies are explained where they are chosen**
  - On `/settings`, confirm each of the three `policy-option` blocks
    (`silent`, `notify`, `announce`) has an adjacent
    `[data-test="policy-explanation"][data-policy="..."]` with
    plain-language text, and that a single
    `[data-test="legal-disclaimer"]` states this is not legal advice.
    Check this while a *different* policy than each option is active, to
    confirm every explanation renders regardless of current selection.

- **Criterion 7375 — Participants hear the recording notice**
  - For "notify": start a microphone capture under the notify policy and
    confirm `[data-test="capture-notice"]` (the on-screen notice) is shown
    while `capturing?` is true.
  - For "announce": as in 7372, confirm `announce-notice-status` shows
    "delivered" before/alongside `capture-status` showing "recording".
  - Note (see Seeds): no real audio is played for the announce policy in
    this build — there is no TTS/beep/sound-playing code in `lib/`. The
    "delivered" status is purely a state label, not an actual audible
    event. This is a real gap worth flagging against the literal criterion
    text ("participants hear the recording notice") — file as `app` scope,
    not `qa` scope, since it's a genuine product gap, not a QA tooling
    problem.

- **Criterion 7376 — Fresh install defaults to the protective policy**
  - This machine's `audio_settings` singleton row will already have been
    touched by the criteria above by the time this is tested. To approximate
    "fresh install" live (without restarting the app, which is out of
    scope), set the policy back toward a neutral state is not possible via
    UI-only reset. Instead: rely on the `Settings` schema declaration
    (`field(:consent_policy, ..., default: :notify)` in
    `lib/ear_witness/audio/settings.ex`) as corroborating evidence, and
    treat the live check as PARTIAL/informational — note in the result that
    a true fresh-install check would require restarting the app with a
    fresh `.config/todo/database.sq3`, which this QA session is not
    permitted to do (no `mix run`/restart). Report the schema-level default
    and whatever the live `/settings` page shows for `active-consent-policy`
    if it happens to already be `notify` from a prior fresh state.

## Result Path

No `result.md` file — findings are filed live via `create_issue` as they're
found, and the run concludes with one `submit_qa_result` call per the
`qa_story` workflow. Screenshots go to
`.code_my_spec/qa/867/screenshots/` (actual landing directory on this box is
`~/Pictures/Vibium/` per a known path quirk — filenames prefixed `QA867-`).

## Setup Notes

- Known tooling quirk: `browser_fill`/rapid phx-change interactions can be
  unreliable back-to-back; pace interactions ~1-2s apart (tracked as issue
  e0d19a51 — do not refile).
- Source files read to ground this brief:
  `lib/ear_witness_web/live/settings_live.ex`,
  `lib/ear_witness_web/live/recording_live/index.ex`, `lib/ear_witness/audio.ex`,
  `lib/ear_witness/audio/consent_policy.ex`, `lib/ear_witness/audio/settings.ex`,
  `lib/ear_witness/audio/tap.ex`, and all six spex files under
  `test/spex/867_stay_on_the_right_side_of_recording_law/`.
