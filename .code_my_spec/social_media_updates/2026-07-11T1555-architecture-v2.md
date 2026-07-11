# EarWitness: Architecture

Against all 10 stories, EarWitness now has 7 bounded contexts and 7 UI surfaces, 
no circular dependencies:

**Getting audio in:** `Audio` (Membrane capture, the system audio tap, and
a pluggable consent policy), `Recordings` (the library — captured, imported,
or bot-retrieved, organized into cases/meetings), `Bots` (dispatch a visible
meeting bot for meetings you can't attend).

**Turning it into attributed text:** `Transcription` (whisper.cpp engine,
durable Oban jobs, editable timestamped segments), `Speakers` (on-device
diarization + voice clustering so recurring people get recognized),
`Models` (in-app model catalog and verified downloads).

**Working with it:** `Search` (FTS over everything), the LiveView surfaces
(library, Otter-style transcript editor with speaker panel, search, first-run
setup, capture settings, bot dispatch) — plus `EarWitnessWeb.McpServer`, a
local MCP tool surface so your AI assistant can search and summarize your
conversations.

Also hardened the BDD boundary for what's coming: framework + project-local
Credo checks deny specs from reaching any internal context (specs drive the
UI like a user), a curated fixtures bridge for the slow seams (whisper runs,
diarization, model downloads, live capture), and a project BDD plan mapping
each story to its legal observable surfaces.

Next: Three Amigos sessions to put acceptance criteria on the stories, then
specs and implementation.
