# Architecture Proposal

Maps the full 10-story backlog (860–869) onto EarWitness — a locally hosted
Otter. Domain layers: getting audio in (Audio capture + Recordings library +
Bots), turning it into attributed text (Transcription + Speakers + Models),
and working with it (Search + the LiveView surfaces + a local MCP surface
for AI assistants). Everything runs on-device (local-first-privacy ADR).

## Contexts

### EarWitness.Recordings

- **Type:** context
- **Description:** The recordings library — every piece of audio the app knows about: captured live, imported from a file, or brought back by a meeting bot. Owns recording metadata, collections (cases/matters/meetings), file placement under the recordings directory, and format normalization for transcription.
- **Stories:** 860, 865

#### Children

- EarWitness.Recordings.Recording (schema) [Stories: 860, 861, 865, 869]: A recording — title, source (captured | imported | bot), file path, duration, status, collection
- EarWitness.Recordings.Collection (schema) [Stories: 865]: A case/matter/meeting grouping recordings, with participants and dates
- EarWitness.Recordings.Importer (module) [Stories: 860]: Copies an external audio file into the library and normalizes it to 16kHz WAV

### EarWitness.Audio

- **Type:** context
- **Description:** Live audio capture — Membrane pipelines over the microphone and the system audio tap (virtual input/output device), device selection, level metering, and the pluggable consent/notification policy that governs when silent capture is allowed.
- **Stories:** 861, 867

#### Children

- EarWitness.Audio.Pipeline (module) [Stories: 860, 861]: Membrane pipeline capturing selected devices (mic and/or tap) into a recording file
- EarWitness.Audio.Tap (module) [Stories: 861]: System audio tap integration — discovers/creates the OS virtual device that exposes output audio for capture
- EarWitness.Audio.ConsentPolicy (module) [Stories: 867]: Pluggable recording consent/notification behavior (silent | notify | announce), consulted before any capture starts
- EarWitness.Audio.PeakDetector (module) [Stories: 861]: Live input level metering for the recording UI

### EarWitness.Transcription

- **Type:** context
- **Description:** On-device transcription and the transcript itself. Wraps whisper.cpp, runs long jobs durably (Oban), stores transcripts as timestamped segments, and owns segment edits (text corrections, speaker reassignment) coming from the editor.
- **Stories:** 860, 863

#### Children

- EarWitness.Transcription.Transcript (schema) [Stories: 860, 863]: Transcript of a recording — status, model/engine metadata, full text projection
- EarWitness.Transcription.Segment (schema) [Stories: 862, 863]: A timestamped utterance — text, start/end, speaker assignment, edit history
- EarWitness.Transcription.Engine (module) [Stories: 860]: Invokes the bundled whisper.cpp binary and parses its JSON output
- EarWitness.Transcription.Worker (module) [Stories: 860]: Oban worker running transcription for one recording with progress updates

### EarWitness.Speakers

- **Type:** context
- **Description:** Who said what — on-device diarization (VAD + speaker-embedding ONNX models via ortex) and speaker identity: clustering voice signatures within a recording and matching them across the library so recurring voices resolve to named people.
- **Stories:** 862

#### Children

- EarWitness.Speakers.Speaker (schema) [Stories: 862, 863]: A named person with a voice signature (embedding centroid) accumulated across recordings
- EarWitness.Speakers.Diarizer (module) [Stories: 862]: Segments a recording by voice (VAD + embeddings + clustering) and tags transcript segments
- EarWitness.Speakers.Identifier (module) [Stories: 862]: Matches diarized clusters against known speakers across the library

### EarWitness.Search

- **Type:** context
- **Description:** Full-text search over the transcript library (SQLite FTS5) with speaker and date filters. Also the query surface the MCP tools call.
- **Stories:** 864, 868

#### Children

- EarWitness.Search.Index (module) [Stories: 864]: Maintains the FTS index as transcripts and edits land, and executes queries with filters

### EarWitness.Models

- **Type:** context
- **Description:** Managed AI model files — the whisper model catalog (size/quality/language tradeoffs) and the diarization ONNX models. Downloads with verification and progress, storage under the app dir, and selection of the active model.
- **Stories:** 866

#### Children

- EarWitness.Models.Catalog (module) [Stories: 866]: Known models with sizes, checksums, and download URLs
- EarWitness.Models.Downloader (module) [Stories: 866]: Downloads and verifies a model with resumable progress

### EarWitness.Bots

- **Type:** context
- **Description:** Meeting bots for meetings the user can't attend — dispatch a bot that joins a call as a visible participant, records it, and deposits the audio into the recordings library for the normal transcription/diarization pipeline.
- **Stories:** 869

#### Children

- EarWitness.Bots.BotSession (schema) [Stories: 869]: A dispatched bot — target meeting URL/platform, schedule, status, resulting recording
- EarWitness.Bots.Runner (module) [Stories: 869]: Drives one bot session — join, capture, leave, hand off audio to Recordings

## Surface Components

### EarWitnessWeb.RecordingLive

- **Type:** live_context
- **Description:** The library UI — browse collections and recordings, start/stop live capture (mic or system tap), import files, kick off transcription, watch job progress.
- **Stories:** 860, 861, 865

#### Children

- EarWitnessWeb.RecordingLive.Index (liveview) [Stories: 860, 861, 865]: Collections + recordings list with record/import actions, capture controls with live level meter, and per-recording status
- EarWitnessWeb.RecordingLive.Show (liveview) [Stories: 860, 865]: One recording — metadata, collection assignment, transcribe action, job progress

### EarWitnessWeb.TranscriptLive

- **Type:** live_context
- **Description:** The Otter-style transcript experience — read the attributed transcript, replay audio behind any segment, fix text inline, and rename/reassign speakers.
- **Stories:** 862, 863

#### Children

- EarWitnessWeb.TranscriptLive.Editor (liveview) [Stories: 862, 863]: Transcript beside audio playback — click-to-play segments, inline text edits, per-segment speaker reassignment
- EarWitnessWeb.TranscriptLive.SpeakerPanel (liveview_component) [Stories: 862, 863]: Name, merge, and recolor the speakers detected in a recording

### EarWitnessWeb.SearchLive

- **Type:** liveview
- **Description:** Search the whole conversation library by phrase, speaker, or date; results jump into the transcript editor at the matching segment.
- **Stories:** 864

### EarWitnessWeb.SetupLive

- **Type:** liveview
- **Description:** First-run experience — pick a transcription model (size/quality guidance), watch it download and verify, and land in a working app minutes after install.
- **Stories:** 866

### EarWitnessWeb.SettingsLive

- **Type:** liveview
- **Description:** Capture settings — input/output/tap device selection and the recording consent/notification policy choice, with plain-language explanation of what each policy means.
- **Stories:** 867

### EarWitnessWeb.BotLive

- **Type:** liveview
- **Description:** Dispatch and monitor meeting bots — paste a meeting link, schedule the bot, watch session status, and jump to the resulting recording.
- **Stories:** 869

### EarWitnessWeb.McpServer

- **Type:** module
- **Description:** Local MCP tool surface for AI assistants — search the library, read transcripts and speaker data, and fetch recording metadata. What leaves the machine is only what the user's own assistant explicitly reads.
- **Stories:** 868

## Dependencies

- EarWitnessWeb.RecordingLive -> EarWitness.Recordings
- EarWitnessWeb.RecordingLive -> EarWitness.Transcription
- EarWitnessWeb.RecordingLive -> EarWitness.Audio
- EarWitnessWeb.TranscriptLive -> EarWitness.Transcription
- EarWitnessWeb.TranscriptLive -> EarWitness.Speakers
- EarWitnessWeb.SearchLive -> EarWitness.Search
- EarWitnessWeb.SetupLive -> EarWitness.Models
- EarWitnessWeb.SettingsLive -> EarWitness.Audio
- EarWitnessWeb.BotLive -> EarWitness.Bots
- EarWitnessWeb.McpServer -> EarWitness.Search
- EarWitnessWeb.McpServer -> EarWitness.Recordings
- EarWitnessWeb.McpServer -> EarWitness.Transcription
- EarWitness.Recordings -> EarWitness.Audio
- EarWitness.Transcription -> EarWitness.Recordings
- EarWitness.Transcription -> EarWitness.Models
- EarWitness.Speakers -> EarWitness.Transcription
- EarWitness.Speakers -> EarWitness.Models
- EarWitness.Search -> EarWitness.Transcription
- EarWitness.Search -> EarWitness.Speakers
- EarWitness.Search -> EarWitness.Recordings
- EarWitness.Bots -> EarWitness.Recordings
