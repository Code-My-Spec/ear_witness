# Qa Story Brief — 862: Know who said what

## Tool

web (Vibium MCP browser tools) — every surface under test is a LiveView
(`RecordingLive.Index/Show`, `TranscriptLive.Editor`) behind the `:browser`
pipeline. `curl` is used only as an up/down probe of the running instance,
never for these session-authenticated routes.

## Auth

Running instance is a stable QA server on `http://localhost:4848`, guarded
by `Desktop.Auth`. First browser navigation must be the login URL with the
current boot key:

    http://localhost:4848/?k=X3HKQM7YH6KXWU5O2622ZENTCHERWJFKDABHUCVGXX6E53LA66CA

That sets the session cookie; browse normally after. For HTTP-level probes:

    .code_my_spec/qa/scripts/qa_login.sh <key>
    .code_my_spec/qa/scripts/authenticated_curl.sh /path

If the key 401s (instance restarted, key rotated), stop and ask the team
lead for a fresh key rather than guessing.

## Seeds

No DB seed script needed — every scenario imports its own WAV fixture
through the real UI (`RecordingLive.Index` upload form, `accept: ~w(.wav)`).
`test/fixtures/diarize.raw` is raw PCM, not a WAV container, so it will NOT
pass the upload's `.wav` filter — do not use it.

Synthetic multi-voice WAV fixtures generated on this box via macOS `say`
(two distinct TTS voices, `Alex` and `Samantha`) + `ffmpeg` (resampled to
16kHz mono 16-bit PCM, the format `EarWitness.Speakers.Diarizer.Onnx`
expects), stored under the scratchpad and uploaded via
`mcp__plugin_codemyspec_vibium__browser_upload`:

- `two-person-hearing.wav` (~26s, six turn-taking lines alternating Alex/
  Samantha) — criteria 7339, 7340.
- `alex_solo1.wav`, `alex_solo2.wav`, `alex_solo3.wav` (~6-7s each, same
  `Alex` voice, three separate recordings) — criteria 7341, 7344
  (cross-recording recognition, then forget-and-reverify).
- `cross-talk-hearing-full.wav` (~12s: clean Alex line, then Alex+Samantha
  `amix`-ed to talk simultaneously over the same time window, then clean
  Samantha line) — criterion 7343 (overlap → "Unknown").

Diarizer is the real pipeline in this instance
(`config :ear_witness, diarizer: EarWitness.Speakers.Diarizer.Onnx` —
`segmentation-3.0.onnx` + WeSpeaker embeddings via `ortex`), not a test
double. Results depend on genuine model output on synthetic TTS audio;
graded as quality observations, not story-failing bugs, unless a finding
is a clear logic bug (crash, non-persistence, wrong-speaker misattribution
that isn't explainable by model variance).

## What To Test

- **7339 — two-person hearing → two distinct speakers.** Import
  `two-person-hearing.wav` via `/recordings` upload form, open the
  recording, click Transcribe, open `/recordings/:id/transcript`. Expect
  the `SpeakerPanel` to show exactly two `[data-test="speaker-chip"]`
  entries and every `[data-test="segment-speaker"]` to match one of them.
- **7340 — naming relabels all segments.** On the same transcript, submit
  `[data-test="speaker-name-form"][data-speaker-id="..."]` with a real name
  (e.g. "Adjudicator") for one detected speaker. Expect the chip to show
  the new name and every segment previously showing that speaker's generic
  label ("Speaker N") to now show the new name, with zero segments left on
  the old generic label.
- **7341 — known voice recognized in a new recording.** Import
  `alex_solo1.wav`, transcribe, open transcript, name the sole detected
  speaker "Alex" via the rename form. Then import `alex_solo2.wav`
  (same voice, new recording), transcribe, open its transcript. Expect the
  segment(s) to already show `[data-test="segment-speaker"]` = "Alex"
  without any manual naming on this second recording.
- **7342 — diarize with no network dependency.** Structural: confirm
  (already read the source) `EarWitness.Speakers`/`Speakers.Diarizer.Onnx`
  take no HTTP client — only `EarWitness.Models`, `EarWitness.Recordings`,
  `EarWitness.Transcription`; the only `Req` usage in `lib/ear_witness/` is
  `models/downloader.ex` (one-time model download, not the diarize path).
  Behaviorally: any successful diarization in this session (all scenarios
  above) is itself evidence the pipeline runs fully on-device — this app
  has no reachable backend to call even if it wanted to.
- **7343 — overlap marked Unknown, not misattributed.** Import
  `cross-talk-hearing-full.wav`, transcribe, open transcript. Expect at
  least one `[data-test="segment-speaker"]` = "Unknown", and "Unknown"
  never appears as a `[data-test="speaker-chip"]` panel entry (i.e. it's
  not a third detected speaker — segments are unattributed, not
  misattributed to a bogus third person). Real-model caveat: `amix`-ed TTS
  audio is adversarial/synthetic overlap, not real simultaneous speech
  from two microphones — grade accuracy leniently, but a *crash* or a
  *confident wrong-speaker* label instead of "Unknown" is a real bug.
- **7344 — deleting a voice signature stops recognition.** Continuing from
  7341 (Alex now named and recognized), click
  `[data-test="delete-voice-signature"][data-speaker-name="Alex"]` in the
  `SpeakerPanel` on either transcript. Then import `alex_solo3.wav` (same
  voice again), transcribe, open its transcript. Expect the segment(s) to
  NOT show "Alex" — either a generic "Speaker N" label or a fresh
  unnamed speaker, but never a resurrected "Alex" attribution.
- Explore freely after the scripted scenarios: reassigning a segment to a
  different speaker via `[data-test="segment-speaker-form"]`, undo/revert
  behavior, and general layout/console-error sanity on
  `/recordings/:id/transcript`.

## Result Path

Findings are filed live via `create_issue` as they're found (per
`qa_story/workflow.md`) — there is no result.md. Screenshots go to
`.code_my_spec/qa/862/screenshots/`. The session ends with one
`submit_qa_result` call carrying the structured `scenarios` list and every
`issue_ids` collected.

## Setup Notes

`.code_my_spec/qa/plan.md` predates the Recordings/Transcription/Speakers
surfaces (still describes the old `TodoLive` UI at `/`) — router confirms
the real routes used here: `/recordings`, `/recordings/:id`,
`/recordings/:id/transcript`. Diarization has no separate UI action; it
runs idempotently the moment `RecordingLive.Show` or `TranscriptLive.Editor`
mounts a completed transcript (`Speakers.diarize_transcript/1`). Cross-
recording matching uses a 0.5 cosine-similarity threshold on WeSpeaker
embeddings (`EarWitness.Speakers` moduledoc) — calibrated from real
measurements, so borderline synthetic-voice matches are plausible and not
automatically a bug.
