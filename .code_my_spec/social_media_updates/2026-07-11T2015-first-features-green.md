# EarWitness: The First Features Are Real (2026-07-11)

Tonight the red bar started turning green. Two stories are now fully
implemented and proven by their own executable specifications —
independently re-run and verified, 17 of 17 scenarios passing:

**Transcribe a hearing recording locally** — import WAV/audio files (corrupt
ones bounce cleanly), record live audio, transcribe on-device through the
whisper.cpp engine behind a swappable seam, timestamped passages, durable
transcripts that survive restarts, background jobs that don't block the UI,
and transcription that only ever starts when you ask for it.

**Keep recordings organized** — tag-style collections (a hearing can live in
its case AND the weekly review), editable titles/dates/participants, a
grouped library view, collection deletes that never touch recordings, and a
30-day trash with restore.

Under the hood that meant building the real domain layer: the Recordings,
Audio (capture sources, consent policies), and Transcription (jobs, editable
segments) contexts, six migrations, and the RecordingLive UI in Tailwind +
DaisyUI — with the implementing agent finding and fixing three of its own
bugs by running the specs, exactly how this is supposed to work.

Also fixed along the way: the desktop auth plug blocking all test clients,
a missing LiveView test dependency, and the discovery that `*_spex.exs`
files need Elixir 1.20's `test_load_filters` to run under `mix test` at all
(framework issue filed for the broken `mix spex` task).

Next: the settings and bot surfaces to unlock the audio-tap story, then the
editor, search, and setup UIs.
