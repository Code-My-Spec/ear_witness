# BDD Specs in EarWitness — Project Plan

How the sealed-spec discipline applies to *this* project. Generic philosophy
and DSL live in the framework docs (`bdd/spex/*` via `read_knowledge`); this
file is the project-specific layer.

## Public surfaces a spec may drive

Specs act as the user acts — through the UI surfaces from the architecture
proposal, driven with `Phoenix.LiveViewTest` inside `EarWitnessSpex.Case`:

- `EarWitnessWeb.RecordingLive.Index` / `.Show` — browse library, start/stop
  capture, import, transcribe (stories 860, 861, 865).
- `EarWitnessWeb.TranscriptLive.Editor` (+ `SpeakerPanel` component) — read
  and fix transcripts, reassign/name speakers (862, 863).
- `EarWitnessWeb.SearchLive` — library search (864).
- `EarWitnessWeb.SetupLive` — first-run model download (866).
- `EarWitnessWeb.SettingsLive` — devices + consent policy (867).
- `EarWitnessWeb.BotLive` — dispatch meeting bots (869).
- `EarWitnessWeb.McpServer` — the MCP tool surface (868); specs call the
  tool functions as an MCP client would and assert on the result tuples.

Not surfaces: `EarWitness.*` contexts, `EarWitness.Repo`, `File`/`Port`/
`:file`. The local Credo check (`EARWIT0001`) enforces this in `_spex.exs`
files; boundary compilation enforces it at module level.

## Fixtures bridge (`EarWitnessSpex.Fixtures`)

The one sanctioned shortcut past the UI, its own top-level Boundary at
`test/support/fixtures/ear_witness_spex_fixtures.ex`. Planned inventory
(delegates land with their contexts):

- `recording_fixture/1` — a completed recording (file on disk + Recording
  row) so transcription/editor specs skip driving a live capture.
- `transcript_fixture/2` — a finished transcript with segments so
  editor/search/MCP specs skip the multi-minute whisper.cpp run.
- `speaker_fixture/1` — a named speaker with a voice signature so
  identification specs have a known person to match.

Keep this list minimal. A fixture for X is only justified when producing X
through the UI would make every downstream spec pay for a slow or
hardware-dependent step (live audio capture, whisper inference, model
download, a bot joining a real meeting).

## Slow/hardware seams — cassette-style substitution

Four operations cannot run for real in specs. Each hides behind its context
and gets substituted at the seam (config-selected module), never in the
spec file:

- whisper.cpp inference (`Transcription.Engine`) — canned JSON output.
- Diarization models (`Speakers.Diarizer`) — canned segment/embedding data.
- Model downloads (`Models.Downloader`) — local test artifact, no network.
- Audio capture (`Audio.Pipeline` / `Audio.Tap`) — fixture WAV files (the
  repo already carries `test/fixtures/*.raw`).

## Legal observable surfaces in `then_`

- LiveView render assertions: `assert render(view) =~ "Transcribing…"`,
  element-scoped asserts on segment text and speaker chips.
- LiveView navigation: search result click patches to the editor at the
  matching segment.
- MCP tool results: `assert {:ok, %{results: [...]}} = ...` on the
  McpServer tool functions.
- PubSub-driven UI updates observed through re-render (job progress) — not
  by subscribing to internal topics.

## Project anti-patterns

- Do NOT seed `Transcription.Segment` rows in `given_` to test the editor —
  use `transcript_fixture/2`; hand-built rows drift from what the engine
  actually emits.
- Do NOT call `EarWitness.Search.Index` to force-index in `given_` —
  indexing is a consequence of transcription completing; assert through the
  UI after the fixture lands.
- Do NOT touch `File` to verify a recording landed on disk — assert what
  the user sees (the recording listed in RecordingLive with its duration).
- Do NOT drive consent-policy behavior by setting config in the spec —
  choose the policy through SettingsLive like a user.
