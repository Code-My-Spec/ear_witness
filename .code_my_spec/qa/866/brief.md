# Qa Story Brief — 866: Working transcriber minutes after install

## Tool

web

## Auth

Navigate once (sets the session cookie for the rest of the session):

    http://localhost:4848/?k=LNBADTLQDLWWDIJKG5X326OPQFFH6PQG2XWIT44YTK3DDG764J4Q

(Key rotates per boot — re-read from the running `qa_server.exs`/desktop QA server output if a 401 is hit. This session was driven against the already-running desktop QA server at `http://localhost:4848`, per the launch instructions — do not restart it.)

## Seeds

No seed script run for this story. The shared QA instance already carries a large amount of state accumulated by prior story QA sessions (dozens of recordings/transcripts, `base` model already downloaded and active, `large-v3-turbo` not downloaded). This means the DB is **not a fresh install** — see Setup Notes for how that constrains criteria 7364/7368/7369/7370.

Relevant catalog facts (from `lib/ear_witness/models/catalog.ex`), needed to plan scenarios without forcing a multi-GB transfer:

- `large-v3-turbo` — default, preselected, `bundled: false`, ~1.6GB, real HF download URL, checksum pinned to a **test-fixture stub, not the real file** (see Setup Notes / filed issue).
- `base` — `bundled: true`, ~148MB, ships in-repo, `downloaded?/1` is always `true` for it — the only way to exercise "download and continue" / "swap models" UI mechanics on this box without a real GB-scale fetch.

## What To Test

- `/setup` — picker renders one `[data-test="model-option"]` per catalog model (2), and no `[data-test="recording-row"]` — criterion 7364.
- `/setup` initial state — `[data-test="selected-model"]` reads `large-v3-turbo` before any click — criterion 7365.
- `/setup`, click the `base` model-option (bundled, already downloaded) — confirms `[data-test="download-button"]` is absent and a `Continue` link (`href="/recordings"`) appears instead, `[data-test="download-status"]` reads `Verified` — partial evidence for 7366's status semantics without a real download.
- `/setup`, with `large-v3-turbo` selected (default) — confirms `[data-test="download-button"]` and `[data-test="download-progress"]` (a `<progress>` element) render, status reads `Not started` — do **not** click it; it triggers a real, uncancellable ~1.6GB fetch from Hugging Face with no cancel control in the UI — criterion 7366, partial.
- Click `Continue` from `/setup` (on `base`) → lands on `/recordings` — criterion 7367 handoff.
- Open an existing transcribed recording (e.g. `/recordings/45`) and confirm real transcript text renders, produced under the currently-active (`base`) model — supporting evidence for 7367's "working transcriber" promise, since a fresh real download+transcribe chain isn't safely exercisable here.
- `/settings` → Transcription model section — confirm `[data-test="active-model-form"]` only lists **downloaded** models as switch targets (currently just `base`) — criterion 7370, partial (can't demonstrate an actual A→B switch without a second downloaded model).
- Code review (router, `RecordingLive.Index` mount, `Models`/`Downloader`) for criteria that aren't safely/fully drivable live: whether `/` gates fresh users into `/setup` (7364), whether recording is unblocked during an in-flight download (7368), and whether the network-interruption seam is reachable outside the test suite (7369) — see Setup Notes.

## Result Path

DB-backed attempt via `submit_qa_result` (per workflow — no result.md file).

## Setup Notes

This is a **shared, long-lived QA instance**, not a fresh install — dozens of recordings and an already-downloaded/active `base` model exist from prior story QA sessions. That blocks true empirical verification of "fresh install" criteria (7364, 7368, 7369, 7370) without either wiping the shared DB (out of scope for this session) or forcing a real ~1.6GB download of `large-v3-turbo` (explicitly out of scope per the launch instructions). Where live verification wasn't possible, this session substitutes targeted source review and states the confidence level explicitly per criterion in the submitted scenario observations.

Two source-confirmed defects were found this way and filed as issues (see submission): (1) nothing in the router or `RecordingLive.Index` gates a fresh/no-model install into `/setup` — `/` always opens the recordings library regardless of `Models.get_active_model()`; (2) `large-v3-turbo`'s pinned checksum (`catalog.ex`) is for a test-fixture stub, not the real Hugging Face file, so a real (non-test-env) download of the recommended default model will deterministically fail checksum verification — confirmed by the module's own doc comment acknowledging this as a placeholder.

The BDD spex for this story already flag the network-drop scenario (7369) as depending on a test-only fixture seam (`EarWitnessSpex.Fixtures.simulate_download_network_interruption/0`) that "isn't stageable through the real UI" — confirmed here: there's no dev/prod config surface for it, and the running app has no distributed node name registered with `epmd`, so there's no way to attach a remote console to flip it out of band either. That scenario's real verification layer is `mix spex`, not live QA.
