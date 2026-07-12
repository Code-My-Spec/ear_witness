# EarWitness.Transcription

On-device transcription of recordings. Wraps the whisper.cpp binary, runs long transcriptions as durable background jobs (Oban), and stores the resulting transcript with timestamped segments for display, search, and inline editing.

## Type

context

## Functions

### transcribe/1

Starts transcription for a recording as a durable background job. Safe to call once per recording — reopening a recording that already has a transcript (any status) never re-queues work.

```elixir
@spec transcribe(EarWitness.Recordings.Recording.t()) ::
        {:ok, Transcript.t()} | {:error, Ecto.Changeset.t()}
```

**Process**:
1. If a transcript already exists for this recording, return it unchanged without enqueuing anything.
2. Otherwise insert a `Transcript` row for the recording with status `:queued`.
3. Enqueue an `EarWitness.Transcription.Worker` Oban job carrying the recording id, so the whisper.cpp invocation and segment persistence happen out of band and survive an app restart.
4. Return the transcript record (its status reflects whatever the job has completed by the time the caller re-reads it — `:queued` if still pending, `:completed` if the job already ran).

**Test Assertions**:
- returns a newly queued transcript for a recording with no existing transcript
- enqueues exactly one Oban job for the recording
- calling it again for a recording that already has a transcript returns the existing transcript and enqueues no additional job
- the caller is not blocked waiting for the job to finish

### get_transcript_for_recording/1

Fetches the transcript for a recording, with segments loaded in playback order, for display in the recording view and the transcript editor.

```elixir
@spec get_transcript_for_recording(recording_id :: integer()) ::
        {:ok, Transcript.t()} | {:error, :not_found}
```

**Process**:
1. Look up the `Transcript` belonging to `recording_id`.
2. Return `{:error, :not_found}` if the recording has not had `transcribe/1` called for it yet.
3. Otherwise preload its segments ordered by start offset and return them with the transcript.

**Test Assertions**:
- returns `{:error, :not_found}` for a recording that has never been transcribed
- returns every segment produced by the engine, each carrying its own timestamp, in playback order
- returns the same persisted transcript and segments on a fresh lookup (a new process/connection), without recomputing anything

### subscribe/1

Subscribes the calling process to status updates for one recording's transcription job, so a LiveView can update without polling as a background job progresses.

```elixir
@spec subscribe(recording_id :: integer()) :: :ok
```

**Process**:
1. Subscribe the caller to a PubSub topic scoped to `recording_id`.
2. `EarWitness.Transcription.Worker` broadcasts on this topic as the job's status changes (`:queued` -> `:transcribing` -> `:completed` or `:failed`).

**Test Assertions**:
- a subscriber receives a broadcast when the job for that recording completes
- a subscriber to one recording's topic receives nothing for another recording's job

### update_segment_text/2

Corrects a segment's text inline, keeping the previous text so it can be undone or reverted later.

```elixir
@spec update_segment_text(segment_id :: integer(), text :: String.t()) ::
        {:ok, Segment.t()} | {:error, Ecto.Changeset.t()}
```

**Process**:
1. Load the segment.
2. Push its current text onto its edit history.
3. Persist `text` as the segment's new current text.

**Test Assertions**:
- the segment's displayed text becomes the corrected text
- the text in place before the edit is retained in history rather than discarded
- editing the same segment a second time adds a second history entry instead of overwriting the first

### reassign_segment_speaker/2

Moves one segment to a different speaker without touching any other segment's attribution.

```elixir
@spec reassign_segment_speaker(segment_id :: integer(), speaker_id :: integer()) ::
        {:ok, Segment.t()} | {:error, Ecto.Changeset.t()}
```

**Process**:
1. Load the segment.
2. Update only its `speaker_id`.
3. Leave every other segment belonging to the same transcript untouched.

**Test Assertions**:
- the targeted segment shows the new speaker afterward
- every other segment on the transcript keeps its original speaker attribution

### revert_segment/1

Restores a segment straight back to exactly what the transcription engine produced, discarding all accumulated edits at once.

```elixir
@spec revert_segment(segment_id :: integer()) :: {:ok, Segment.t()} | {:error, Ecto.Changeset.t()}
```

**Process**:
1. Load the segment.
2. Set its current text back to the immutable machine-heard text captured when the transcript was created.
3. Clear its edit history, since there is nothing left to step back through.

**Test Assertions**:
- reverting a segment that has been edited multiple times restores the engine's original text, not the most recent edit
- the corrected text is no longer shown once reverted
- reverting a segment with no edits leaves its text unchanged

### undo_last_edit/1

Walks back the single most recent text edit anywhere on a transcript, one step at a time, regardless of which segment it touched.

```elixir
@spec undo_last_edit(transcript_id :: integer()) :: {:ok, Segment.t()} | {:error, :no_history}
```

**Process**:
1. Find whichever segment on the transcript has the most recently added history entry.
2. Pop that entry and restore it as the segment's current text.
3. Return `{:error, :no_history}` once no segment on the transcript has any history left.

**Test Assertions**:
- after two edits to the same segment, the first undo restores the first correction, not the original text
- a second undo then restores the original machine-heard text
- undo acts on the most recently edited segment transcript-wide, not a fixed segment
- returns `{:error, :no_history}` once every edit on the transcript has been undone

## Dependencies

- EarWitness.Recordings
- EarWitness.Models

## Components

### EarWitness.Transcription.Transcript

Transcript of a recording — status (`:queued` | `:transcribing` | `:completed` | `:failed`), model/engine metadata, and a full-text projection over its segments.

### EarWitness.Transcription.Segment

A timestamped utterance — current text, immutable machine-heard text, start/end offsets, speaker id, and the edit history that `update_segment_text/2`, `revert_segment/1`, and `undo_last_edit/1` operate on.

### EarWitness.Transcription.Engine

Invokes the bundled whisper.cpp binary against a normalized audio file and parses its JSON output into segments. Selected via the `config :ear_witness, :transcription_engine` seam so specs can replay recorded real output instead of running the NIF.

### EarWitness.Transcription.Worker

Oban worker that runs one recording's transcription job: calls the Engine, persists the Transcript and its Segments, and broadcasts status changes over PubSub for `subscribe/1` listeners.
