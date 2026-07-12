# EarWitness: The QA Loop Draws Blood, and the App Gets Its Face (2026-07-12)

Two things happened overnight that belong together.

**QA found what specs structurally couldn't.** Per-story QA drives the
REAL app — real microphone, real whisper.cpp, real browser — where the
specs deliberately substitute seams. Round one: live capture was broken
end-to-end (Membrane wrote headerless raw audio; the failure was silently
swallowed). Round two, after that fix was byte-level verified: the dev
server's code reloading had unloaded the whisper NIF (Erlang forbids NIF
reloads), exposing a second real gap — an engine crash left transcripts
stuck at "transcribing" forever with no error and no way out. Both fixed:
captures finalize to proper WAV, crashes land in a visible failed state
with a working "Retry transcription" button. The QA agent also caught its
own subagent filing a fictional work report — verified against the
database, kept the real findings, discarded the fiction.

**And the redesign landed.** EarWitness now wears the house style shared
with the operator's other products: the Workshop theme (petrol teal,
bronze, sage on warm limestone — light and dark), self-hosted IBM Plex
Sans and JetBrains Mono, a proper drawer-sidebar shell with theme toggle,
heroicons, and color-cycled speaker chips in the transcript editor. Built
in an isolated worktree so QA never saw pixels move mid-test, merged only
after the full 69-scenario suite passed against the new markup — every
data-test contract preserved.

The loop continues: story 860's final QA pass is running against the
rebuilt app right now, with nine stories queued behind it.
