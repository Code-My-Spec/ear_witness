# EarWitness.Search

Full-text search over the transcript library (SQLite FTS5) with speaker and date filters. Also the query surface the MCP tools call.

## Type

context

## Dependencies

- EarWitness.Recordings
- EarWitness.Speakers
- EarWitness.Transcription

## Functions

### search/2

Full-text search across transcript segments and recording metadata (title, collection, speaker names), returning ranked hits with enough context to render without opening a recording. `search/1` is the same function with `opts` defaulted to `[]`.

```elixir
@type segment_hit :: %{
        type: :segment,
        recording_id: binary(),
        recording_title: String.t(),
        segment_id: binary(),
        speaker: String.t() | nil,
        timestamp: non_neg_integer(),
        snippet: String.t()
      }
@type recording_hit :: %{
        type: :recording,
        recording_id: binary(),
        recording_title: String.t(),
        matched_field: :title | :collection | :speaker,
        snippet: String.t()
      }
@spec search(query :: String.t(), opts :: keyword()) :: [segment_hit() | recording_hit()]
```

**Process**:
1. Normalize `query` for FTS5 `MATCH` syntax
2. Query the index for segment-text matches and, separately, recording-metadata matches (title, collection name, collection participant names)
3. When `opts[:speaker]` is given, keep only hits attributed to that speaker (segment hits by segment speaker; recording hits by collection participant)
4. When `opts[:from]`/`opts[:to]` (`Date.t()`) are given, keep only hits on recordings dated within that inclusive range
5. Build `segment_hit` structs (recording id/title, segment id, speaker, timestamp, a snippet with the match in context) for transcript-text matches, and `recording_hit` structs (matched_field indicating whether the title, collection, or a participant name matched) for metadata matches
6. Return the combined, ranked list

**Test Assertions**:
- a phrase said in several transcribed recordings returns a hit naming each recording's title (criterion 7352)
- filtering by speaker returns only hits attributed to that speaker (criterion 7353)
- filtering by a date range that includes the matching recordings keeps their hits (criterion 7353)
- filtering by a date range entirely in the past (excluding the matching recordings) returns no hits (criterion 7353)
- each segment hit carries a snippet, the recording title, and a timestamp (criterion 7354)
- the snippet contains the matched phrase in context (criterion 7354)
- a segment hit's `recording_id` and `segment_id` are sufficient to open the transcript editor scrolled to that segment (criterion 7355)
- a query matching only a recording's title returns a `recording_hit` (`matched_field: :title`), not a `segment_hit` (criterion 7357)
- after a segment's text is corrected, searching the corrected wording returns a hit for that segment, and searching the original replaced wording returns no hit (criterion 7356)
- a query matching only a recording's collection name returns a `recording_hit` (`matched_field: :collection`), not a `segment_hit`
- a query matching only a name in a recording's collection participants, with no title or transcript-text match, returns a `recording_hit` (`matched_field: :speaker`), not a `segment_hit`

### index_recording/1

Adds or refreshes a recording's title, collection name, and collection participant names in the index, so it participates in title/collection/participant matching. Called whenever a recording is created, imported, or renamed, or its collection (including its participant list) changes.

```elixir
@spec index_recording(recording :: EarWitness.Recordings.Recording.t()) :: :ok
```

**Process**:
1. Upsert the recording's id, title, collection name, and (if it belongs to a collection) that collection's participant names into the index's recording-metadata entry, replacing any prior values for that recording
2. Return `:ok`

**Test Assertions**:
- a recording indexed with a given title is findable by a partial, case-insensitive match on that title (criterion 7357)
- indexing a renamed recording replaces the previously searchable title text
- a recording indexed with a collection's participant names is findable by a case-insensitive match on any one of those names

### index_transcript/1

Indexes every segment of a finished transcript — text, speaker attribution, and timestamp — making the recording's spoken content searchable. Called once transcription completes.

```elixir
@spec index_transcript(transcript :: EarWitness.Transcription.Transcript.t()) :: :ok
```

**Process**:
1. Read the transcript's segments
2. For each segment, resolve its `speaker_id` to a display name via `EarWitness.Speakers` (`nil` if unattributed), then upsert the segment's text, resolved speaker name, and timestamp into the index, keyed by segment id and associated with the transcript's recording
3. Return `:ok`

**Test Assertions**:
- a phrase spoken in a freshly transcribed recording is findable via `search/2` once transcription completes, with one hit per recording that contains it (criterion 7352)

### reindex_segment/1

Replaces one segment's indexed text and speaker after an inline correction or speaker reassignment, so search reflects the edited transcript rather than the original machine output.

```elixir
@spec reindex_segment(segment :: EarWitness.Transcription.Segment.t()) :: :ok
```

**Process**:
1. Resolve the segment's `speaker_id` to a display name via `EarWitness.Speakers` (`nil` if unattributed), then upsert the segment's current text and resolved speaker name into the index, replacing whatever was previously indexed for that segment id
2. Return `:ok`

**Test Assertions**:
- after a segment's text is corrected, `search/2` finds it by the corrected wording (criterion 7356)
- after a segment's text is corrected, `search/2` no longer finds it by the original, replaced wording (criterion 7356)

## Components

### EarWitness.Search.Index

The SQLite FTS5-backed store behind this context: holds the searchable text (segment content and recording metadata) plus the filterable attributes (speaker, date, recording id) that `search/2`, `index_recording/1`, `index_transcript/1`, and `reindex_segment/1` read from and write to.
