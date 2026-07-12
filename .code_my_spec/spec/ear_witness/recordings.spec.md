# EarWitness.Recordings

The recordings library — every piece of audio the app knows about, whether captured live from the microphone (via the Membrane audio pipeline), imported from an external file (e.g. an ordered hearing recording), or dropped off by a meeting bot. Owns recording metadata, collection ("case/matter/meeting") grouping, file placement under the recordings directory, and format normalization for the transcription engine.

## Type

context

## Dependencies

- EarWitness.Audio

## Functions

### import_recording/2

Validates an externally-sourced audio file, normalizes it to 16kHz WAV, copies it into the recordings directory, and registers it as a new recording.

```elixir
@spec import_recording(Path.t(), String.t()) ::
        {:ok, EarWitness.Recordings.Recording.t()}
        | {:error, :invalid_audio_file | Ecto.Changeset.t()}
```

**Process**:
1. Delegate to `EarWitness.Recordings.Importer` to read and structurally validate the file at `upload_path` (a real audio file, not arbitrary bytes)
2. On structural failure, return `{:error, :invalid_audio_file}` immediately without copying anything or touching the database
3. Normalize the audio to 16kHz mono WAV and copy the result into the recordings directory
4. Compute duration from the normalized file's sample count and sample rate
5. Insert a `Recording` with `source: :imported`, the original `filename`, the new file path, computed duration, and `status: :active`
6. Return `{:ok, recording}`

**Test Assertions**:
- a well-formed WAV upload produces a recording whose title reflects the original filename and whose duration reflects the file's declared sample count and rate
- a file with no RIFF/WAVE header returns `{:error, :invalid_audio_file}`
- after a rejected import, the library's recording set is unchanged from before the attempt — no partial row, no orphaned file
- a WAV file whose header declares a three-hour duration at a low sample rate is imported with that full duration, independent of the file's byte size

### create_recording/1

Registers an already-captured, already-normalized audio file as a new recording. Used both when live capture (via `EarWitness.Audio`) finishes and when a bot session (`EarWitness.Bots`) hands off its recording — neither case needs `Importer`'s validation/normalization because the file is already known-good.

```elixir
@spec create_recording(map()) ::
        {:ok, EarWitness.Recordings.Recording.t()} | {:error, Ecto.Changeset.t()}
```

**Process**:
1. Accept `attrs` including `file_path`, `duration`, and `source` (`:captured` or `:bot`), plus optional display metadata (`title`, `date`, `participants`)
2. Insert a `Recording` with `status: :active` and the given source
3. Return `{:ok, recording}` or `{:error, changeset}` on validation failure

**Test Assertions**:
- given a finished capture's file path and duration, returns a recording with `source: :captured` that immediately appears in `list_recordings/0`
- the resulting recording waits in an untranscribed state — no transcript is created as a side effect

### get_recording/1

Fetches a single recording by id, preloaded with its collection memberships.

```elixir
@spec get_recording(term()) ::
        {:ok, EarWitness.Recordings.Recording.t()} | {:error, :not_found}
```

**Process**:
1. Query the recording by id, preloading `:collections`
2. Return `{:error, :not_found}` if no active or trashed recording matches
3. Return `{:ok, recording}` otherwise

**Test Assertions**:
- returns the recording with its current title, date, participants, duration, and collection list
- returns `{:error, :not_found}` for an id that was never created
- a recording fetched immediately after `update_recording/2` reflects the update, and still does after being re-fetched independently (simulating a fresh app session against the same durable store)

### list_recordings/0

Lists every active (non-trashed) recording, regardless of collection membership. The general-purpose lookup surface for other contexts (`EarWitness.Transcription`, `EarWitness.Search`) and `EarWitnessWeb.McpServer`.

```elixir
@spec list_recordings() :: [EarWitness.Recordings.Recording.t()]
```

**Process**:
1. Query recordings where `status == :active`
2. Return the list, most recently created first

**Test Assertions**:
- a freshly imported recording appears in the result
- a trashed recording does not appear in the result
- a restored recording reappears in the result

### list_collections/0

Lists every collection, each preloaded with its active member recordings, for grouped library browsing.

```elixir
@spec list_collections() :: [EarWitness.Recordings.Collection.t()]
```

**Process**:
1. Query all collections, preloading `:recordings` filtered to `status == :active`
2. Return the list

**Test Assertions**:
- a collection with one member recording preloads that recording
- the same recording preloads under every collection it belongs to, unduplicated as a database row (same recording id in each group)
- a collection whose only member was just trashed still appears in the result, with an empty recording list, rather than disappearing

### list_uncategorized_recordings/0

Lists active recordings that belong to no collection.

```elixir
@spec list_uncategorized_recordings() :: [EarWitness.Recordings.Recording.t()]
```

**Process**:
1. Query active recordings with zero collection memberships
2. Return the list

**Test Assertions**:
- a recording with no collections appears in the result
- a recording belonging to at least one collection does not appear in the result
- a recording appears here again once its last remaining collection is deleted

### update_recording/2

Updates a recording's editable metadata — title, date, and participants.

```elixir
@spec update_recording(EarWitness.Recordings.Recording.t(), map()) ::
        {:ok, EarWitness.Recordings.Recording.t()} | {:error, Ecto.Changeset.t()}
```

**Process**:
1. Build a changeset from `recording` and `attrs` restricted to `title`, `date`, `participants`
2. Persist and return `{:ok, recording}`, or `{:error, changeset}` on validation failure

**Test Assertions**:
- updating title, date, and participants together persists all three
- the updated title is what subsequently appears via `list_recordings/0` and `list_collections/0`, not the original
- the update survives an independent re-fetch via `get_recording/1`

### set_recording_collections/2

Replaces a recording's full collection membership with exactly the given set. Membership is multi-select ("tag-style") — a recording may belong to any number of collections at once.

```elixir
@spec set_recording_collections(EarWitness.Recordings.Recording.t(), [term()]) ::
        {:ok, EarWitness.Recordings.Recording.t()} | {:error, Ecto.Changeset.t()}
```

**Process**:
1. Replace the recording's collection-membership join rows with exactly `collection_ids` (full replace, not additive)
2. Return `{:ok, recording}` with `:collections` preloaded to the new set

**Test Assertions**:
- setting `[collection_id]` on a recording with no prior memberships adds it to that one collection
- setting two collection ids at once puts the recording in both simultaneously, each independently listing it under `list_collections/0`
- setting `[]` clears all memberships and the recording reappears in `list_uncategorized_recordings/0`
- the recording's id is identical across every collection group it renders under — one recording, never duplicated

### create_collection/1

Creates a new collection ("case/matter/meeting").

```elixir
@spec create_collection(map()) ::
        {:ok, EarWitness.Recordings.Collection.t()} | {:error, Ecto.Changeset.t()}
```

**Process**:
1. Build a changeset from `attrs` (`name` required; `date`, `participants` optional)
2. Persist and return `{:ok, collection}`, or `{:error, changeset}` on validation failure

**Test Assertions**:
- creating a collection with a name, date, and participants makes it appear in `list_collections/0`
- the new collection starts with zero member recordings

### delete_collection/1

Deletes a collection without cascading to its member recordings — deleting a case is a structural-only operation.

```elixir
@spec delete_collection(EarWitness.Recordings.Collection.t()) ::
        {:ok, EarWitness.Recordings.Collection.t()} | {:error, Ecto.Changeset.t()}
```

**Process**:
1. Delete the collection's membership join rows
2. Delete the collection row itself
3. Return `{:ok, collection}` — no recording row is touched

**Test Assertions**:
- after deletion, the collection no longer appears in `list_collections/0`
- every recording that belonged to it still appears in `list_recordings/0`, still fetchable via `get_recording/1` with its metadata intact
- a recording whose only collection was deleted moves into `list_uncategorized_recordings/0`

### trash_recording/1

Soft-deletes a recording — moves it to the trash rather than destroying it, per the 30-day retention policy.

```elixir
@spec trash_recording(EarWitness.Recordings.Recording.t()) ::
        {:ok, EarWitness.Recordings.Recording.t()} | {:error, Ecto.Changeset.t()}
```

**Process**:
1. Set `status: :trashed` and `trashed_at: DateTime.utc_now()`
2. Persist without touching the file on disk, the recording's metadata, or its collection memberships
3. Return `{:ok, recording}`

**Test Assertions**:
- a trashed recording no longer appears in `list_recordings/0`, `list_collections/0`, or `list_uncategorized_recordings/0`
- a trashed recording appears in `list_trashed_recordings/0`
- its title, date, participants, and collection memberships are unchanged after trashing (verified by a subsequent `restore_recording/1`)

### list_trashed_recordings/0

Lists recordings currently in the trash, most recently trashed first.

```elixir
@spec list_trashed_recordings() :: [EarWitness.Recordings.Recording.t()]
```

**Process**:
1. Query recordings where `status == :trashed`
2. Return the list

**Test Assertions**:
- a recording sent to the trash appears here with its `trashed_at` timestamp, from which the trash page computes days remaining against the fixed 30-day retention window
- a restored recording no longer appears here

### restore_recording/1

Restores a trashed recording back to the working library, exactly as it was.

```elixir
@spec restore_recording(EarWitness.Recordings.Recording.t()) ::
        {:ok, EarWitness.Recordings.Recording.t()} | {:error, Ecto.Changeset.t()}
```

**Process**:
1. Set `status: :active`, clear `trashed_at`
2. Persist without modifying metadata or collection memberships
3. Return `{:ok, recording}`

**Test Assertions**:
- a restored recording reappears in `list_recordings/0`
- a restored recording that belonged to a collection before trashing reappears grouped under that same collection in `list_collections/0`, without needing membership to be re-set
- a restored recording no longer appears in `list_trashed_recordings/0`

## Components

### EarWitness.Recordings.Recording

A recording — title, source (`:captured` | `:imported` | `:bot`), file path, duration, lifecycle status (`:active` | `:trashed`) with `trashed_at`, date, and participants. Belongs to zero or more collections.

### EarWitness.Recordings.Collection

A case/matter/meeting grouping recordings — name, date, participants. Has a multi-membership (many-to-many) relationship to recordings; deleting one never deletes its members.

### EarWitness.Recordings.Importer

Reads and structurally validates an external audio file, normalizes it to 16kHz mono WAV, and places the result under the recordings directory. Used only by `import_recording/2` — captured and bot-sourced audio arrive already normalized and skip this step.
