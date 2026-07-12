# Qa Story Brief

Story 864 — "Find anything ever said" (library-wide transcript search, `/search`, `EarWitnessWeb.SearchLive`).

## Tool

web

`/search` is a LiveView on the `:browser` pipeline — use MCP browser tools
(`mcp__plugin_codemyspec_vibium__browser_*`) exclusively for the search UI
and the transcript editor it links into. No `:api` routes are involved.

## Auth

App is already running at http://localhost:4848 (desktop shell). Login
first via browser navigation to:

    http://localhost:4848/?k=LNBADTLQDLWWDIJKG5X326OPQFFH6PQG2XWIT44YTK3DDG764J4Q

This sets the session cookie for subsequent navigation. If it 401s, the
key has rotated (app restart) — stop and get a fresh key rather than
guessing.

`.code_my_spec/qa/scripts/qa_login.sh` / `authenticated_curl.sh` exist for
curl-based smoke checks only (e.g. confirming `/` 401s pre-login) — not for
exercising `/search` itself, per the golden rule (session-authenticated
LiveView routes are browser-tool-only).

## Seeds

No new seeds required. Direct read-only inspection of
`.config/todo/database.sq3` (via `sqlite3 -readonly`, from the project
root — the DB path is cwd-relative) shows 45 existing recordings/transcripts
from prior QA sessions, already indexed into the FTS5 tables
(`search_segments`: 77 rows, `search_recordings`: 45 rows). This is enough
existing signal to cover every criterion without transcribing anything new,
which also sidesteps the known VAD "no speech" bug on short clips
(5ef6fdb4/79bea285).

Confirmed via direct SQL query (read-only, for test planning only — all
assertions happen through the UI):

- Query **"evidence"** hits 4 segments across 4 different recordings
  (ids 29, 32, 37, 45), with 4 different speaker labels (`Speaker 1`,
  `Speaker 2` ×2, `Tenant`) for what is in each transcript literally the
  same underlying speaker turn ("Understood. We will review the
  photographic evidence in this limited day.") — this is the documented
  diarization-imperfection limitation, and is exactly the shape needed to
  prove the speaker *filter* narrows correctly (filter to `Tenant` → only
  recording 45's hit) without asserting diarization accuracy.
- Query **"witness"** hits 3 recordings by title only (`witness-recording-1/2/3.wav`,
  ids 33/34/35) — recording-level hits, no segment text match.
- All 45 recordings were inserted today (2026-07-12, 03:47–13:22); the
  date filter compares `date(inserted_at)` (day granularity — see
  `EarWitness.Search.Index`), so a range that excludes today should zero
  out results, proving the filter is live.
- Recording 45 ("two-person-hearing-fred-samantha.wav") has segment id 76,
  text "Understood. We will review the photographic evidence in this
  limited day.", speaker "Tenant" — used for the correction test.

## What To Test

- **(a) Phrase search hits across multiple recordings** — navigate to
  `/search`, type `evidence` into `#search-form input[name=q]`. Expect
  ≥4 `[data-test="search-result"]` cards spanning ≥3 distinct
  `[data-test="result-recording-title"]` values.
- **(c) Readable without opening** — on those same results, confirm each
  card shows `[data-test="result-snippet"]`, `[data-test="result-recording-title"]`,
  and `[data-test="result-timestamp"]` with real (non-empty, sensible)
  values.
- **(b) Speaker filter** — with `evidence` still queried, fill
  `#search-filters input[name=speaker]` with `Tenant`. Expect the result
  set to narrow to exactly recording 45's hit (confirms the filter
  mechanism narrows to the attributed label, not diarization accuracy
  per se — documented limitation).
- **(b) Date filter** — clear the speaker filter. Set
  `#search-filters input[name=from]` and `input[name=to]` to a date range
  that excludes today (e.g. `2026-07-01`–`2026-07-01`). Expect zero
  results even though `evidence` still matches. Reset to include today
  (e.g. `2026-07-12`–`2026-07-12`) and confirm results reappear —
  demonstrates the filter is wired and actually filters, given all seed
  data shares one calendar day.
- **(d) Jump into transcript** — click a `[data-test="search-result"] a`
  for one of the "evidence" hits. Expect navigation to
  `/recordings/:id/transcript?segment=:id`, with
  `[data-test="transcript"]` present and
  `[data-test="focused-segment"]` containing the matched text ("...
  photographic evidence...").
- **(f) Find recording by title** — clear filters, search `witness`.
  Expect 3 `[data-test="recording-result"]` cards for
  `witness-recording-1/2/3.wav`.
- **(e) Corrected word becomes findable** — from a search-result jump (or
  direct navigate) open recording 45's transcript editor. Search first to
  confirm a distinctive not-yet-present word (e.g. `zephyrwatch`) has zero
  hits. Then use `[data-test="segment-editor"][data-segment-id="76"]`
  (`input[name="segment[text]"]` + Save) to rewrite segment 76's text to
  include that word. Return to `/search`, search the new word, and expect
  a fresh hit on recording 45/segment 76 — proves the index follows edits
  (`EarWitness.Search.reindex_segment/1` on `update_segment_text/2`).
  Afterward, click `[data-test="revert-button"][data-segment-id="76"]` to
  restore the original text (leave QA data as found).
- Explore freely afterward: empty query, whitespace-only query, a query
  matching nothing, rapid successive filter changes.

## Result Path

No result.md — findings go through `create_issue` as discovered; final
outcome recorded via `submit_qa_result`. Screenshots (evidence only) go to
`.code_my_spec/qa/864/screenshots/`.

## Setup Notes

`SearchLive` currently requires a non-empty query for filters to take
effect (`results_for("", _filters), do: []` in
`lib/ear_witness_web/live/search_live.ex`) — filters alone with an empty
query correctly show nothing; this is expected, not a bug, but worth
confirming isn't surprising in the UI (no filters-only affordance).
