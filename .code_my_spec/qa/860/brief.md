# Qa Story Brief — Story 860: Transcribe a hearing recording locally

## Tool

web

## Auth

App runs at `http://localhost:4848` (fixed port, running instance — do not
start a new one). Guarded by `Desktop.Auth` (random per-boot login key).

1. Browser (Vibium): navigate once to
   `http://localhost:4848/?k=TH4J2KFMP3JTK5PH45Z6MG2223PQ7NZEYDEIQ56R6YZZBYYMLIYA`
   to set the session cookie, then browse normally.
2. curl-level spot checks: run
   `.code_my_spec/qa/scripts/qa_login.sh TH4J2KFMP3JTK5PH45Z6MG2223PQ7NZEYDEIQ56R6YZZBYYMLIYA`
   once, then `.code_my_spec/qa/scripts/authenticated_curl.sh /path` for
   subsequent requests. Unauthenticated requests return `401 Unauthorized`.

Note: `.code_my_spec/qa/plan.md`'s selector list is STALE (describes the old
`/` TodoLive page). Real routes for this story: `/recordings` (library,
import form, record/stop) and `/recordings/:id` (show page, transcribe
action, transcript). Selectors below were re-probed from the running
`RecordingLive.Index`/`RecordingLive.Show` source
(`lib/ear_witness_web/live/recording_live/{index,show}.ex`) and confirmed
live via curl against the authenticated session.

## Seeds

No seed script needed for this story — the library is exercised by
importing fresh files through the UI. The shared app/DB instance already
has other test data in it; do not delete anything not created by this
session.

Generate a real speech WAV for an honest end-to-end whisper.cpp run:

    say -o /tmp/qa.aiff "testing one two three" && afconvert -f WAVE -d LEI16@16000 -c 1 /tmp/qa.aiff /tmp/qa.wav

Generate a corrupt file for the rejection scenario:

    echo "not audio" > /tmp/qa-corrupt.wav

Prefix all recording titles/filenames created during this session with
`QA860-` (e.g. `QA860-hearing.wav`) so they're identifiable and don't
collide with other data in the shared instance.

## What To Test

Selectors (re-probed from `lib/ear_witness_web/live/recording_live/index.ex`
and `show.ex`, confirmed via authenticated curl against the live page):

- Index (`/recordings`): import form `#import-form` /
  `[data-test="import-form"]`, file input `input[type=file][name=audio_file]`
  (native `accept=".wav"` — client-side hint only), import error
  `[data-test="import-error"]`, recording rows `[data-test="recording-row"]`
  (containing filename text + `[data-test="recording-duration"]`), Record
  button (`phx-click="record"`), Stop button (`phx-click="stop"`, disabled
  until recording starts), capture error `[data-test="capture-error"]`.
- Show (`/recordings/:id`): title `[data-test="recording-title"]`,
  duration `[data-test="recording-duration"]`, transcribe button
  `[data-test="transcribe-button"]` (only rendered when no transcript
  exists yet), job status `[data-test="job-status"]` (shown while
  `status != :completed`), transcript container `[data-test="transcript"]`
  (shown only when `status == :completed`), each passage
  `[data-test="transcript-segment"]` with its own
  `[data-test="segment-timestamp"]`.

Scenarios (map to acceptance criteria + Three Amigos rules for story 860):

1. **Import a WAV of real speech** — navigate to `/recordings`, upload
   `/tmp/qa.wav` via the import form, submit. Expect: new row appears in
   Uncategorized with title `qa.wav` (rename via metadata form on Show to
   `QA860-hearing` afterward for traceability) and a duration badge, no
   `import-error`.
2. **Reject a corrupt file cleanly** — upload `/tmp/qa-corrupt.wav`.
   Expect: `[data-test="import-error"]` renders a real message (not a
   crash/500), library still shows only the recordings that existed
   before this attempt (corrupt file's row does NOT appear).
3. **Import waits for explicit transcribe** — open the just-imported
   recording's Show page before clicking anything. Expect:
   `[data-test="transcript"]` is ABSENT, `[data-test="transcribe-button"]`
   IS present (i.e., nothing transcribes automatically on import).
4. **Trigger transcription and observe background/non-blocking behavior**
   — click `[data-test="transcribe-button"]`. Expect: UI updates promptly
   (button replaced by `[data-test="job-status"]` or reflects a
   queued/processing state) without hanging; navigate back to
   `/recordings` and confirm the rest of the app (other pages, other
   buttons) remains responsive while the whisper.cpp job runs in the
   background (this is a real Oban-backed job against the base.en model,
   not mocked — expect the run to take some real wall-clock time for even
   a few seconds of audio).
5. **Timestamped transcript** — once `status == :completed`, expect
   `[data-test="transcript"]` to render with one or more
   `[data-test="transcript-segment"]` rows, each carrying its own
   `[data-test="segment-timestamp"]` (count of segments == count of
   timestamps).
6. **Transcript persists across reload** — after transcription completes,
   reload `/recordings/:id` (hard `browser_navigate` or `browser_reload`).
   Expect: transcript still shows without re-transcribing (no
   `transcribe-button` reappears, segments/timestamps identical).
7. **On-device / no network transcription** — this is whisper.cpp running
   in-process against the local `models/` dir; there is no network call
   involved in the transcribe path (confirm by reading
   `lib/ear_witness/transcription/worker.ex` if present, and by noting in
   evidence that the UI never references an external transcription
   service/API key). No traffic-sniffing required — this is primarily a
   code/behavior observation, not a live network probe.
8. **Format support check (informational)** — the import file input's
   native `accept` attribute is `.wav` only, and
   `EarWitness.Recordings.Importer`/`WavHeader` only parse WAV headers
   (`lib/ear_witness/recordings/importer.ex`,
   `lib/ear_witness/recordings/wav_header.ex`) — there is no MP3/M4A/OGG/
   FLAC decode path in the codebase today. Note this gap against the
   "Import accepts WAV/MP3/M4A/OGG/FLAC" expectation rather than assuming
   it works; do not spend excess time trying to force non-WAV uploads
   past the client-side filter since the server-side importer will
   reject them as `:invalid_audio_file` regardless.
9. **General import/record/transcribe flow smoke** — confirm the Record/
   Stop buttons render (do not necessarily complete a live capture unless
   an input device is available in this environment — note whichever path
   is observed: successful capture, or the `[data-test="capture-error"]`
   "No input device is available." message), and confirm the Cases
   (collections) section and Uncategorized section render without error.

## Result Path

No `result.md` file — findings are filed live via `create_issue` as
discovered, and the session concludes with one
`mcp__plugin_codemyspec_local__submit_qa_result` call carrying the
`scenarios` list and all `issue_ids`. Screenshots (evidence) go to
`.code_my_spec/qa/860/screenshots/`; any non-image evidence (curl output,
worker source excerpts) goes to `.code_my_spec/qa/860/responses/`.

## Setup Notes

- The app instance and its SQLite DB are SHARED with other work — do not
  delete or wipe data not created by this session. Prefix all QA-created
  recording titles with `QA860-`.
- Screenshot destination is unverified per `plan.md` — if
  `browser_screenshot` doesn't land at the expected path, check
  `~/Pictures/Vibium/<basename>` as a fallback and copy/note the real path
  in the issue/evidence trail.
- Transcription runs the real whisper.cpp NIF (base.en model) — expect
  real (if short) processing latency, not instant completion. Poll/wait
  for `[data-test="transcript"]` rather than assuming immediate
  completion after clicking Transcribe.
- Multi-hour transcription (criterion 7327) and interrupted-transcription
  resume (criterion 7330) are impractical to exercise live in a QA
  session (would require hours of audio or a live app-restart mid-job);
  these are covered by the passing spex suite (contract-level) and are
  called out as `partial`/not-exercised in the live scenario list rather
  than faked.
