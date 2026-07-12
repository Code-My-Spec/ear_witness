# Meeting bot join via a config-selected relay seam

## Status
Proposed

## Context
Story 869 ("Send a bot to the meetings I can't attend") dispatches a bot
that joins a real third-party meeting (Zoom/Meet/Teams) as a visible
participant, records it, and hands the audio to the recordings library.
No vendor integration for actually joining a meeting exists yet, and
picking one (native platform bot APIs vs. a hosted meeting-bot relay
vendor vs. a browser-automation joiner) is a research decision, not
something to guess at while wiring up `EarWitness.Bots`.

## Options Considered
- **Hosted meeting-bot relay vendor (e.g. Recall.ai-style API)** — fastest
  path to multi-platform support (Zoom/Meet/Teams) without maintaining
  platform-specific bot code, at the cost of a third party touching
  meeting audio in flight (tension with the local-first-privacy ADR;
  needs its own retention-policy scrutiny — see story 869 criterion 7389).
- **Native per-platform bot SDKs** — best privacy story (audio goes
  straight to this app), but multiplies integration and maintenance work
  per meeting platform.
- **Browser automation (join as a headless participant, capture the tab's
  audio)** — no vendor dependency, but fragile against UI changes and
  against waiting-room/anti-bot measures.

## Decision
Proposed: `EarWitness.Bots.Runner` calls its join behavior through a
config-selected seam (`config :ear_witness, :bot_relay`, mirroring the
`:transcription_engine` seam). Until a vendor/approach is chosen via a
`research_topic` pass, the production relay
(`EarWitness.Bots.Runner.Relay`) honestly returns
`{:error, "not connected to a real meeting platform yet"}` rather than
pretending to join — a dispatched bot session in a real deployment fails
fast with a clear reason instead of hanging. Specs stage join/record/leave
outcomes directly through `EarWitness.Bots` (see
`EarWitnessSpex.Fixtures.simulate_bot_*/1`), the same honest-seam pattern
used for `EarWitness.Speakers.Diarizer` and `EarWitness.Models.Downloader`
network-interruption staging, since no spec can drive a real external
meeting.

## Consequences
- Meeting-bot dispatch is not usable end to end until this seam gets a
  real implementation — the UI and `EarWitness.Bots` context are ready,
  but every real dispatch will fail with the not-implemented reason.
- Whichever option is chosen later must be re-examined against
  `local-first-privacy` (a hosted relay vendor is a real exception to "no
  audio leaves the device" that needs an explicit, disclosed carve-out).
