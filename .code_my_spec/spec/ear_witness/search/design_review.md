# Design Review

## Overview

Reviewed the `EarWitness.Search` context and its single child component, `EarWitness.Search.Index` (SQLite FTS5-backed store), against the architecture proposal, the context-design rules (including the project's no-scope-struct override), and story 864's BDD specs (criteria 7352–7357). Two real gaps were found between what the context promised callers and what the `Index` child actually supported; both were fixed directly in the spec files. The design is now sound and ready for implementation.

## Architecture

- Clean separation of concerns: `EarWitness.Search` owns query normalization orchestration and shaping raw rows into `segment_hit`/`recording_hit` structs; `EarWitness.Search.Index` owns the FTS5 virtual table(s) and raw MATCH execution. This split is stated explicitly in `Index`'s own description and is honored consistently across both specs.
- Component typing is correct: the context is `context`-typed with public functions and a single child `module` (`Index`) that is a thin storage/query primitive with no business shaping of its own — the right pattern for a search-index component.
- `Dependencies` (`EarWitness.Recordings`, `EarWitness.Speakers`, `EarWitness.Transcription`) all correspond to real contexts in the architecture proposal, and the proposal's own dependency graph (`EarWitness.Search -> EarWitness.Recordings/Speakers/Transcription`) matches — the earlier amendment adding `Recordings` (for title/collection search) is reflected on both sides.
- `Index`'s own dependency (`EarWitness.Repo`) follows the same convention used by sibling contexts (`Models`, `Audio`), so it checks out even though `Repo` isn't itself a modeled architecture component.
- Project override honored: no function in either spec takes a scope struct, consistent with the EarWitness no-auth/no-multi-tenancy override at the top of `context_design.md`.
- **Found and fixed — cross-context type mismatch (context spec).** `index_transcript/1` and `reindex_segment/1` accept `EarWitness.Transcription.Segment.t()` and previously treated its `speaker` as if already a display string. But `EarWitness.Transcription`'s own spec (`reassign_segment_speaker(segment_id, speaker_id)`) shows a segment's speaker is stored as a `speaker_id`, while `Index.upsert_segment/1` and `segment_hit.speaker` require `String.t() | nil`. The `EarWitness.Speakers` dependency existed to cover exactly this resolution but the Process steps never used it. Fixed by adding an explicit "resolve `speaker_id` to a display name via `EarWitness.Speakers`" step to both functions' Process sections.
- **Found and fixed — delegate/API mismatch (context vs. child).** `search/2`'s own description and Process promised recording-level matching on title, collection, *and* speaker/participant name (`recording_hit.matched_field :: :title | :collection | :speaker`, plus "recording hits by participant" under the `opts[:speaker]` filter), but `Index.upsert_recording/1` only ever stored title/collection, and `Index.query/2` never searched or filtered on anything participant-related. Resolved by threading `Recordings.Collection`'s existing `participants` field through `index_recording/1` → `Index.upsert_recording/1` (new `participants: [String.t()]` field) and through `Index.query/2`'s MATCH and `opts[:speaker]` filtering. This reuses data already owned by the already-declared `Recordings` dependency, so no new dependency was introduced.

## Integration

- `EarWitnessWeb.SearchLive` and `EarWitnessWeb.McpServer` both depend on `EarWitness.Search` per the proposal; `search/2`'s public shape (ranked `segment_hit`/`recording_hit` list) is a reasonable, storage-agnostic surface for both a LiveView and an MCP tool to consume.
- Write path: `index_recording/1`, `index_transcript/1`, and `reindex_segment/1` are the context's ingestion API, called by `Recordings` (on create/import/rename/collection or participant change), `Transcription` (on transcript completion), and the edit flow (on inline correction/speaker reassignment) respectively. Each now correctly delegates to a matching `Index` primitive (`upsert_recording/1` or `upsert_segment/1`).
- Read path: `search/2` delegates to `Index.query/2` for raw MATCH rows (now consistently covering segment text, segment speaker, and all three recording-metadata fields) and shapes them into hit structs — the delegation now matches on both sides after the fixes above.
- One open integration item, not blocking: nothing in the current specs (`Recordings.Collection` is a bare schema stub with no functions yet) shows what calls `index_recording/1` when a collection's participant list changes independently of a recording rename. The `index_recording/1` description now states this trigger explicitly; whoever implements `Recordings.Collection`'s participant-editing function should call it. Flagging for the `Recordings` spec owner rather than fixing here, since it's outside this component's file scope.

## Stories

- Criterion 7352 (phrase hits across multiple recordings): covered by `search/2` and `index_transcript/1` test assertions.
- Criterion 7353 (narrow by speaker and date range): covered by `search/2` test assertions and `Index.query/2`'s speaker/date filtering.
- Criterion 7354 (results readable without opening): covered by `search/2`'s `segment_hit` type (snippet, title, timestamp) and matching test assertions.
- Criterion 7355 (jump from hit to transcript): covered — `segment_hit.recording_id`/`segment_id` are asserted sufficient to locate the segment.
- Criterion 7356 (corrected words become findable): covered by `reindex_segment/1` and `search/2` test assertions.
- Criterion 7357 (find a recording by title): covered by `search/2` and `index_recording/1`. The criterion's own doc-comment notes search should also cover collections and speaker/participant names (PM decision, Three Amigos 2026-07-11) — this wasn't backed by the `Index` child until this review's fixes; it now is, via the new collection/participant test assertions in both specs.

## Issues

- **Fixed — missing speaker-id resolution.** `index_transcript/1` and `reindex_segment/1` in `search.spec.md` implied passing a segment's `speaker` straight through, but `Transcription.Segment` stores a `speaker_id`, not a name. Added an explicit resolution step via `EarWitness.Speakers` to both functions' Process sections.
- **Fixed — recording-level participant search unsupported by `Index`.** `search/2` promised `recording_hit.matched_field: :speaker` and speaker-based filtering of recording hits ("by participant"), but `Index.upsert_recording/1` and `Index.query/2` had no participant data or matching path. Added `participants: [String.t()]` to `upsert_recording/1`'s param map and to its Process/Test Assertions, and extended `query/2`'s MATCH and `opts[:speaker]` filtering to cover participant rows, threaded from `Recordings.Collection.participants` via `index_recording/1`. Corresponding test assertions were added to `search.spec.md` for the new `recording_hit(matched_field: :collection)` and `recording_hit(matched_field: :speaker)` cases.
- No other type mismatches, misplaced functions, contradictory test assertions, or missing/invalid dependencies were found.

## Conclusion

Ready for implementation. Both defects found during review were fixed directly in `search.spec.md` and `search/index.spec.md`; the context's public API, its delegation to `Index`, and story 864's acceptance criteria are now mutually consistent. The one remaining note (wiring `index_recording/1` into a future `Recordings.Collection` participant-edit function) is an action item for the `Recordings` spec owner, not a blocker for `Search`/`Index` implementation.
