# EarWitness.Search.Index

The SQLite FTS5-backed store behind `EarWitness.Search`: holds the searchable text (segment content and recording metadata) plus the filterable attributes (speaker, date, recording id) that the context's `search/2`, `index_recording/1`, `index_transcript/1`, and `reindex_segment/1` read from and write to. This module owns the FTS5 virtual table(s) and raw query execution; the parent context owns shaping raw rows into `segment_hit`/`recording_hit` structs.

## Type

module

## Functions

### upsert_segment/1

Writes or replaces one segment's indexed row — text, speaker, and timestamp, keyed by segment id and associated with its recording. Backs the context's `index_transcript/1` (once per segment) and `reindex_segment/1`.

```elixir
@spec upsert_segment(%{
        segment_id: binary(),
        recording_id: binary(),
        text: String.t(),
        speaker: String.t() | nil,
        timestamp: non_neg_integer()
      }) :: :ok
```

**Process**:
1. Build (or update) the FTS5 row for `segment_id`, storing the given text, speaker, timestamp, and recording_id.
2. Replace any previously indexed row for the same `segment_id` rather than inserting a duplicate.
3. Return `:ok`.

**Test Assertions**:
- a segment indexed once is findable by a `query/2` MATCH on its text
- indexing the same `segment_id` again with different text replaces the previous entry rather than adding a second one
- the indexed row carries the segment's speaker and timestamp

### upsert_recording/1

Writes or replaces one recording's indexed metadata — title, collection name, and collection participant names — keyed by recording id. Backs the context's `index_recording/1`.

```elixir
@spec upsert_recording(%{
        recording_id: binary(),
        title: String.t(),
        collection: String.t() | nil,
        participants: [String.t()]
      }) :: :ok
```

**Process**:
1. Build (or update) the FTS5 metadata row for `recording_id`, storing its title, collection name, and participant names.
2. Replace any previously indexed row for the same `recording_id`.
3. Return `:ok`.

**Test Assertions**:
- a recording indexed with a given title is findable by a partial, case-insensitive `query/2` MATCH on that title
- indexing the same `recording_id` again with a new title replaces the previously searchable text
- a recording indexed with participant names is findable by a case-insensitive `query/2` MATCH on any one of those names, distinguishable from a title/collection match

### query/2

Runs an FTS5 MATCH query against both the indexed segment text and the indexed recording metadata (title, collection, participants), with optional speaker and date-range filters, returning raw matching rows — each identifying which field matched — for the context to shape into hits. `query/1` is the same function with `opts` defaulted to `[]`.

```elixir
@spec query(match :: String.t(), opts :: keyword()) :: [map()]
```

**Process**:
1. Normalize `match` for FTS5 `MATCH` syntax.
2. Run the MATCH against the segment-text rows and, separately, the recording-metadata rows (title, collection, and participant names).
3. When `opts[:speaker]` is given, restrict segment rows to that speaker, and restrict recording-metadata rows to recordings whose indexed participants include that speaker.
4. When `opts[:from]`/`opts[:to]` (`Date.t()`) are given, restrict rows to recordings dated within that inclusive range.
5. Return the raw matching rows (segment rows and recording-metadata rows, each tagged with which field matched), ranked by FTS5 relevance.

**Test Assertions**:
- a MATCH query returns a row for every indexed segment containing the phrase
- filtering by speaker excludes segment rows attributed to a different speaker
- filtering by a date range excludes rows for recordings dated outside it
- a query matching only indexed recording-metadata title text returns a metadata row tagged as a title match, not a segment row
- a query matching only indexed recording-metadata participant text returns a metadata row tagged as a participant match, distinct from a title or collection match
- when `opts[:speaker]` is given, a title-matching metadata row is excluded unless that speaker is among the recording's indexed participants

## Dependencies

- EarWitness.Repo
