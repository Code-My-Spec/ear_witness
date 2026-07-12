# Qa Story Brief — 863: Fix the transcript like Otter

## Tool

web (Vibium MCP browser tools) — every surface under test is a LiveView
(`RecordingLive.Index/Show`, `TranscriptLive.Editor`) behind the `:browser`
pipeline. `curl` is used only as an up/down probe and for read-only HTML
inspection of already-authenticated pages, never to drive interactions.

## Auth

Running instance on `http://localhost:4848`, guarded by `Desktop.Auth`.
First browser navigation must be the login URL with the current boot key:

    http://localhost:4848/?k=X3HKQM7YH6KXWU5O2622ZENTCHERWJFKDABHUCVGXX6E53LA66CA

That sets the session cookie; browse normally after. For HTTP-level probes:

    .code_my_spec/qa/scripts/qa_login.sh <key>
    .code_my_spec/qa/scripts/authenticated_curl.sh /path

If the key 401s (instance restarted, key rotated), stop and ask the team
lead for a fresh key rather than guessing.

## Seeds

No DB seed script needed. Every scenario imports its own WAV fixture
through the real UI (`RecordingLive.Index` upload form, `accept: ~w(.wav)`)
and transcribes it with the real whisper.cpp + diarizer pipeline (no test
doubles) — this is the running desktop instance, not ExUnit.

Fixtures built this session (macOS `say` + `afconvert`/`ffmpeg`, 16kHz mono
16-bit PCM), stored under the QA agent's scratchpad:

- `QA863-single.wav` (13.9s, one continuous `say -v Samantha` call, no
  inserted pauses) — imported as recording id 24. Produces exactly one
  segment. Used for the single-segment criteria (7345, 7348, 7349, 7350).
- `QA863-two-speaker.wav` (~16s, four `ffmpeg`-concatenated turns
  alternating `say -v Samantha` / `say -v Fred`) — imported as recording id
  28. Produces 4 segments but only ONE detected speaker (see Setup Notes —
  blocked by bug d0d3bfa7).
- Two earlier fixture attempts (`QA863-single-v2.wav` with embedded
  `[[slnc 700]]` pauses, `QA863-single-v3.wav` a bare 4-clip concat) both
  came back "No speech was detected" — see issue 79bea285. Not used for
  scenario evidence; kept only as repro artifacts.

Pre-existing recordings left over from story 862's QA session were reused
for multi-segment scenarios that don't depend on speaker attribution:

- Recording 20 (`alex_long1.wav`, 3 segments: ids 15, 16, 17) — used for
  click-to-play (7347) and follow-along highlighting (7351). Its speaker
  labels show "Unknown" (a prior session forgot its only speaker — see
  issue e5e5f8b1), which is irrelevant to these two scenarios since they
  only assert the `[data-test="playing-segment"]` marker, not speaker
  labels.

## What To Test

- **7345 — fix a mis-heard word inline.** On `/recordings/24/transcript`,
  fill `[data-test="segment-editor"][data-segment-id="22"] input[name="segment[text]"]`
  with corrected text and submit. Expect the segment's own text to update
  and the old text to disappear.
- **7346 — move a segment to the right speaker.** Requires 2+ detected
  speakers on one transcript. Import a multi-voice WAV, transcribe, open
  `/recordings/:id/transcript`, check `[data-test="speaker-chip"]` count.
  If only 1 speaker is detected (expected, given bug d0d3bfa7), instead
  verify the `[data-test="segment-speaker-form"] select` renders a valid,
  non-empty option list matching the detected speaker(s) rather than
  attempting an unreachable 2-option reassign.
- **7347 — click a passage to hear it.** On a multi-segment transcript
  (recording 20), click one `[data-test="transcript-segment"]` container
  and confirm only that segment's nested `[data-test="playing-segment"]`
  marker appears — no other segment shows it.
- **7348 — edits persist after a restart.** Edit a segment's text, then do
  a real navigate-away-and-back (not just a DOM re-render) to the same
  `/recordings/:id/transcript` URL. Confirm the edited text is still shown
  and the pre-edit text is gone.
- **7349 — undo walks back through edits.** Edit the same segment twice in
  a row, click `[data-test="undo-button"]` once and confirm the
  *intermediate* text shows (not the original, not the second edit), click
  undo again and confirm it's back to the original machine-heard text.
- **7350 — revert a segment to what the machine heard.** After editing a
  segment away from its original text, click
  `[data-test="revert-button"][data-segment-id="..."]` and confirm the
  segment shows exactly the original transcribed text, with the edited
  text gone.
- **7351 — follow-along highlighting during playback.** On the same
  multi-segment transcript, click a second segment while a first is
  already marked playing; confirm the `[data-test="playing-segment"]`
  marker relocates onto the new segment and off the old one.

## Result Path

No `result.md` — findings are filed via `create_issue` as discovered and
the run is closed with `submit_qa_result` (task id
`a8f4dc43-6040-4122-bea4-dbf9457c94d3`). Screenshots live under
`.code_my_spec/qa/863/screenshots/` in intent, but Vibium's screenshot tool
on this box always writes to `~/Pictures/Vibium/<filename>` regardless of
the path given (known quirk, issue 0c18ac81) — all evidence for this
session is there, prefixed `QA863-`.

## Setup Notes

**Diarization collapse (bug d0d3bfa7) blocks full coverage of 7346.** A
freshly-built two-voice WAV (`QA863-two-speaker.wav`, alternating
`say -v Samantha` / `say -v Fred` turns, clearly distinct voices) was
imported and transcribed live on this instance and still diarized to a
single `Speaker 1` covering all 4 segments — reconfirming the filed HIGH
bug is still present on the current build (a fix exists but is
uncommitted, in progress, in a teammate's worktree — not on this running
instance). Criterion 7346 could not be exercised as a real 2-speaker
reassignment; the reassignment dropdown itself was verified to render
correctly for the single-speaker case instead.

**Bug e5e5f8b1 (empty dropdown after forgetting the only speaker)**
reconfirmed live and traced as the explanation for several stray
"Unknown"-speaker recordings left over from story 862's QA session:
forgetting a transcript's last speaker permanently empties every segment's
reassignment `<select>` on that transcript, with no self-heal on reload
(`diarize_transcript/1` is a no-op once `diarized_at` is set). Still
accurately described by the existing issue; not re-filed.

**Two new bugs filed this session:**
- No in-app link from `RecordingLive.Show` to `TranscriptLive.Editor` —
  the editor is only reachable by hand-typing `/recordings/:id/transcript`
  or via a SearchLive hit. Issue 93fce947.
- Clicking "Save" on a segment's inline text-edit form also marks that
  segment as "playing" — the Save button has no `phx-click` of its own, so
  the click bubbles to the parent segment div's `phx-click="play_segment"`.
  The Revert button (which does carry its own `phx-click`) does not have
  this problem. Issue 2f3ff5ed.
- Also filed (story 860 territory, not blocking): "No speech was detected"
  reproduces on 11-14s clips with internal pauses, not just the ~6s clips
  the existing issue 5ef6fdb4 describes. Issue 79bea285.
