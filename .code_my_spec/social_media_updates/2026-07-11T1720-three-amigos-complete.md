# EarWitness: Example Mapping Complete — Every Story Has Its Rules (2026-07-11)

Ten Three Amigos sessions in one afternoon, PM answering from his phone
between fixing the installer tooling upstream. Every story in the backlog
now carries business rules and Given/When/Then scenarios, and the open
product questions got answered instead of parked:

- **Transcription is always manual** — nothing churns your CPU uninvited.
- **Import formats:** WAV/MP3/M4A/OGG/FLAC.
- **Audio tap tech:** Core Audio process taps on macOS, WASAPI loopback on
  Windows — both v1.
- **Voice recognition on by default** (it's all local), with deletable
  voice signatures and honest "unknown speaker" for low-confidence audio.
- **Editor:** full undo history, per-segment revert to the machine text,
  follow-along highlighting during playback.
- **Search:** stemmed + prefix matching over transcripts, titles,
  collections, and speaker names — and edits are searchable.
- **Organization:** tag-style collections (a hearing can live in its case
  AND the weekly review), plus a 30-day trash.
- **First run:** guided model download, large-v3-turbo recommended.
- **Consent:** defaults to notify; silent capture is an explicit, lawful
  choice; announce mode plays an audible notice.
- **MCP:** stdio transport (no network port at all), read + one write tool
  (assistant can attach summaries), user-revocable.
- **Meeting bot:** joins visibly, runs locally if at all possible, and any
  external relay may only pipe audio through — never store it.

Score: 58 rules, 65 scenarios, one open research card (the Zoom/Meet/Teams
bot join mechanism). Next stop on the graph: BDD specs and implementation.
