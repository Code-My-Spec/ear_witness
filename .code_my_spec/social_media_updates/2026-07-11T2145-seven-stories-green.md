# EarWitness: Seven Stories Green, 58/69 Scenarios Passing (2026-07-11)

The scoreboard tonight: **860, 861, 864, 865, 866, 867, 869 fully green.**
That's local transcription, tap capture, search, collections, first-run
model setup, consent law, and the meeting bot — all proven by their own
executable specs.

The best story of this stretch was a fight between two scenarios. The
implementing agent declared criteria 7366 ("show progress, verify checksum")
and 7368 ("keep recording while the download runs") *mathematically
incompatible* and sacrificed one. They weren't incompatible — together they
demand what a real product needs anyway: a genuinely asynchronous download.
The fix: LiveView `start_async` for the download await, `render_async` where
specs need completion, and — the fun part — a **gated cassette plug** that
physically holds the replayed HTTP transfer mid-flight, so "a download is
still running" is true the way it's true for a real 1.6GB model on hotel
wifi, not a timing accident. Plus one real bug the conversion surfaced: the
awaiting task was never subscribed to the progress PubSub it was waiting on.

Model downloads themselves follow the record-once/replay-forever philosophy:
ReqCassette replays a recorded HTTP interaction with checksum verification,
network-interruption recovery, and retry — no hand-written fake responses
anywhere in the suite.

Remaining red: the MCP assistant surface (6 scenarios, next up) and real
multi-speaker diarization (5 scenarios — the one genuinely hard algorithmic
piece left).
