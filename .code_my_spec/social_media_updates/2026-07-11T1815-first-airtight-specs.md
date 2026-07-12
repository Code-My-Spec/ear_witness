# EarWitness: First Specs, Held to an Airtight Standard (2026-07-11)

The first BDD specs landed — 11 executable Given/When/Then scenarios for the
founding story ("Transcribe a hearing recording locally") — and then got a
hostile review, because the first specs set the bar for every spec after
them.

What the review caught and fixed:

- **A theater test.** The "transcribe with networking disabled" scenario
  set an `:offline` flag that disabled nothing. Reframed: the no-network
  guarantee is structural (the transcription context has no HTTP client to
  phone home with), and the spec now pins the actual engine output.
- **Prose assertions.** `page =~ "Transcript"` passes for all the wrong
  reasons. Every scenario now asserts a `data-test` selector contract the
  UI must implement — the specs define the interface before it exists.
- **Undeclared hardware seams.** Live-capture scenarios now name the
  substitution point (fixture audio instead of portaudio) instead of
  pretending a CI box has a microphone.

And the transcription-testing decision, straight from the PM: **doubles
replay recorded reality.** The spec-level engine substitute plays back JSON
captured from the actual whisper.cpp NIF running the actual model on the
repo's fixture audio — assertions pin words whisper really said ("Testing
1, 2, 3."). Hand-written fake output is banned; the real engine keeps its
own integration test.

All 11 scenarios compile, pass the sealed-boundary Credo checks, and fail
red — which is the point. The red bar is the to-do list for
implementation. Nine stories of specs to go.
