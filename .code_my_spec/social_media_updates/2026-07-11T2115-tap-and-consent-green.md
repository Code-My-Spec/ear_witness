# EarWitness: The Original Requirement Works (2026-07-11)

The story that started this whole product — record both sides of your own
calls through a system audio tap, with no bot in the participant list — is
green. All six scenarios pass, along with all six consent-policy scenarios,
independently verified.

What that means concretely:

- Pick the system audio tap (or plain microphone) as your capture source in
  settings; captures are tagged with their source and channel makeup
  ("microphone + system audio").
- Every capture start is governed by your consent policy: **silent** where
  lawful, **notify** (the protective default on a fresh install), or
  **announce** — which delivers an audible notice into the call and refuses
  to record if the notice can't be delivered. Refusal, never silent
  fallback.
- Plain-language policy explanations with a not-legal-advice disclaimer,
  right where you choose.
- No tap installed? Guided setup instead of a dead end. No input device?
  A clear message, no phantom recordings.

Running tally: **five stories fully green** (local transcription, tap
capture, search, collections/trash, consent law), the editor at 6/7. In
flight: model-download setup, the meeting bot, the MCP assistant surface,
and real multi-speaker diarization — the last hard algorithmic nut.
