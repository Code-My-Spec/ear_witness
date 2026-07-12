# EarWitness: The Headline Feature Actually Works Now (2026-07-12)

QA on story 862 caught the bug that mattered most: on a clean two-voice
recording — two genuinely distinct macOS voices, proper silence between
turns, transcription correctly splitting it into six segments —
diarization collapsed everyone into ONE speaker. "Know who said what" was
the product's headline capability, and it didn't. The BDD spec never saw
it, because the spec's recorded cassette had two speakers baked in.

Root cause was subtle and real: within-recording clustering ran on the
segmentation model's activation profiles, which look nearly identical
across clean solo turns (the model reuses the same local speaker slot),
so clustering picked k=1 before voice embeddings — the thing that actually
distinguishes people — ever got a vote. Cross-recording recognition passed
precisely because it used those embeddings.

The fix: cluster on per-turn voice embeddings, and — a second problem only
real audio revealed — sparsify the affinity graph so the speaker-count
selection survives real embeddings' baseline cross-similarity. Validated on
three real scenarios: two voices → two speakers, one voice → one, and the
existing conversation fixture unchanged. Cassettes re-recorded from the
fixed pipeline. 69/69 green.

Also fixed from the editor QA pass: a missing link to the transcript editor,
and a click-bubbling bug where hitting Save quietly stole the "now playing"
marker.

Two stories QA-passed, more re-verifying now against the fixes. The pattern
holds: specs prove the logic, QA proves the product, and the gap between
them is exactly where the real bugs live.
