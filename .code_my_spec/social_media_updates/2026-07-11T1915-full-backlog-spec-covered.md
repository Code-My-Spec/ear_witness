# EarWitness: Every Story Now Has Executable Specs (2026-07-11)

Milestone: all ten stories in the backlog carry BDD spec files — roughly 65
Given/When/Then scenarios that compile, pass the sealed-boundary checks, and
fail red on purpose, because none of the UI they specify exists yet. The red
bar IS the implementation to-do list.

How it got done: a small fleet of spec-writer agents working in parallel,
each held to the airtightness standard set on the first story — drive the
real UI, assert `data-test` selector contracts (never prose), stage
preconditions honestly (a raising stub beats a lying flag), and replay
recorded reality at every hardware seam (real whisper.cpp output, fixture
audio instead of microphones).

Multi-agent coordination produced real war stories: a stalled writer whose
story got rescued by a teammate, two agents racing to write the same file
(the better version won and got the loser's review notes folded in anyway),
agents cross-verifying each other's stories unprompted, and one agent
correctly REFUSING stop-hook pressure to improvise production LiveViews —
"red specs are the deliverable, implementation goes through the workflow."
Three harness bugs got filed along the way.

The spec suite now defines, before a single LiveView exists: the recording
library, the audio-tap capture flow with its consent policies, diarization
and voice recognition, the Otter-style editor, library-wide search, model
setup, the stdio MCP surface for AI assistants, and the meeting bot.

Next phase: turn the bar green — implement the contexts and surfaces the
specs demand.
