# Qa Story Brief — 865 Keep recordings organized

## Tool

web

## Auth

Navigate ONCE to establish the session cookie:

    http://localhost:4848/?k=LNBADTLQDLWWDIJKG5X326OPQFFH6PQG2XWIT44YTK3DDG764J4Q

(Key provided by the running QA server for this session — per `.code_my_spec/qa/plan.md`, the `Desktop.Auth` key rotates per boot; if a 401 is hit, re-navigate to the `/?k=...` URL above rather than assuming a new key is needed.) After that, browse normally at `http://localhost:4848/recordings`, `/recordings/:id`, `/recordings/trash`.

## Seeds

No context-specific seed script exists yet for Recordings/Collections —
`priv/repo/qa_seeds.exs` only seeds legacy `Todo` rows (stale; not
relevant to this story). Test data is created live through the UI during
this session:

- Import real audio via the "Import a recording" form on `/recordings`
  using the file input (`data-test="import-form"`, `.wav` accepted).
  Use the repo's own sample WAV as upload fixture (small, real audio):

      /Users/johndavenport/Documents/github/desktop-example-app-main/c_src/ear_witness/whisper.cpp/samples/jfk.wav

  Re-upload the same file multiple times (once per hearing needed) —
  each import creates a new recording titled after the uploaded
  filename initially (title is editable per criterion 7359).
- Cases ("collections") are created live via the "Cases" form on
  `/recordings` (`data-test="collection-form"`, fields
  `collection[name]`, `collection[date]`, `collection[participants]`).

## What To Test

- **7358 — Create a case and add hearings to it**
  - Import two recordings via the Import form on `/recordings`.
  - Create a case via the Cases form (name, date, participants), e.g.
    "Smith v. Landlord". Expect it to appear under
    `[data-test="collection"]`.
  - Open the first recording's Show page, check its box under
    `[data-test="recording-collections-form"]` /
    `[data-test="collection-option"]` for the new case. Expect
    `[data-test="recording-collection"]` badge to show the case name.
  - Repeat for the second recording.
  - Return to `/recordings` and confirm both recordings render nested
    under the case's `[data-test="collection"]` block.

- **7359 — Edit a recording's metadata**
  - Open a recording's Show page. Use the single combined form
    `[data-test="recording-metadata-form"]` (fields `recording[title]`,
    `recording[date]`, `recording[participants]`) to change all three
    at once and submit.
  - Expect `[data-test="recording-title"]`, `[data-test="recording-date"]`,
    `[data-test="recording-participants"]` to reflect the new values
    immediately.
  - Return to `/recordings` and confirm the new title is what's shown in
    the row (old filename/title no longer appears).
  - Reload the Show page directly and confirm the edit persisted.

- **7360 — One recording appears in two collections**
  - Create two cases (e.g. "123 Main St Case" and "Weekly Review").
  - On one recording's Show page, check both case checkboxes in the
    same `set_collections` form submit (or two sequential toggles —
    note which the real UI supports, since the form is `phx-change`
    with no separate submit button).
  - Expect both `[data-test="recording-collection"]` badges to appear
    on the Show page.
  - On `/recordings`, expect the SAME recording (same
    `data-recording-id`) to render once under each case's
    `[data-test="collection"]` block — two DOM rows, one underlying id.

- **7361 — Browse the library by collection**
  - With at least one categorized and one uncategorized recording,
    open `/recordings`.
  - Expect the categorized recording under its
    `[data-test="collection"]`, and the uncategorized one under
    `[data-test="uncategorized-recordings"]` — not both, not neither.

- **7362 — Removing a case keeps its recordings**
  - With a case containing one recording, click
    `[data-test="delete-collection-button"][data-collection-id=...]`
    on `/recordings`.
  - Expect the case block to disappear from the page.
  - Expect the recording that was in it to still be listed (now under
    Uncategorized, presumably) and to still open normally at its Show
    URL with its title intact.

- **7363 — Restore a recording from the trash**
  - On a recording's Show page, click
    `[data-test="delete-recording-button"]`. Expect navigation back to
    `/recordings` and the recording gone from the working library.
  - Open `/recordings/trash`. Expect
    `[data-test="trash-retention-notice"]` to state a "30 day"
    retention window, and the recording listed under
    `[data-test="trash-row"]`.
  - Click `[data-test="restore-button"]` on that row. Expect the row to
    disappear from the trash page.
  - Return to `/recordings` and confirm the recording is back in the
    working library (and still under whatever case it belonged to, if
    any — worth checking whether trash/restore preserves case
    membership, which is not explicitly asserted by the BDD spec).

- **Exploratory / edge cases** (not required by acceptance criteria but
  worth a quick look):
  - Submitting the Cases form with an empty name.
  - Deleting a case with zero recordings in it.
  - What happens to a trashed recording's case membership badges.
  - Whether a recording can be un-checked from a case (removed from
    collection) via the same `set_collections` form.

## Result Path

DB-backed attempt via `submit_qa_result` (see workflow doc) — findings
filed via `create_issue` as discovered. Screenshots saved under
`.code_my_spec/qa/865/screenshots/` (filenames prefixed `QA865-`; actual
save location may redirect to `~/Pictures/Vibium/` per the vibium
tooling quirk noted in the task).

## Setup Notes

- The linked component is `EarWitnessWeb.RecordingLive.Show`
  (`lib/ear_witness_web/live/recording_live/show.ex`); the library/
  trash/case UI mostly lives in the sibling
  `EarWitnessWeb.RecordingLive.Index`
  (`lib/ear_witness_web/live/recording_live/index.ex`,
  `live_action`s `:index` and `:trash`) — read both, the story spans
  the pair.
- `.code_my_spec/qa/plan.md`'s App Overview section describing `/` as
  `TodoLive` is stale for this story — the recordings library now
  lives at `/recordings` (router: `live "/recordings", RecordingLive.Index,
  :index`, `live "/recordings/trash", RecordingLive.Index, :trash`,
  `live "/recordings/:id", RecordingLive.Show, :show`). The
  `Desktop.Auth` key-based login mechanism it describes is unchanged
  and confirmed working for this session.
- `phx-change` inputs (the collections checkbox form in particular) can
  be unreliable under rapid successive `browser_fill`/`browser_click` —
  pace interactions ~1-2s apart (issue e0d19a51).
