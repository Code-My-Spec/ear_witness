# EarWitness: 69/69. Every Scenario Green. (2026-07-11)

The final boss fell tonight. Real multi-speaker diarization — the thing the
ADR filed away as "needs research" — is implemented, and with it the last
five red scenarios. **All 69 BDD scenarios across all ten stories pass.**

What "real" means here, because it matters:

- One whole-file pass of the pyannote segmentation model (via ortex/ONNX)
  produces per-frame speaker classes; **actual spectral clustering** —
  cosine affinity, normalized graph Laplacian, eigendecomposition, eigengap
  k-selection, k-means — keeps identities consistent across a recording.
  Validated against a genuine 30-second two-person recording with real
  cross-talk: 16 turns, all correctly attributed. (The first attempt
  collapsed everything to one speaker — Nx returns eigenvalues in
  descending order. The fixture caught it, because the fixture is real.)
- **Cross-recording voice recognition** via WeSpeaker ResNet34 voice
  embeddings, fed by a from-scratch Kaldi-style log-mel feature extractor,
  with the match threshold calibrated from measured same-speaker vs
  different-speaker similarities — not a number copied from a paper.
- The spec doubles replay **recorded output from real diarizer runs**
  (regenerable by a checked-in script), keeping the house rule intact:
  hand-written fake data never enters this test suite.

So: name the adjudicator once, and the next hearing recognizes their voice.
Delete a voice signature and recognition stops. Cross-talk gets an honest
"Unknown," never a guess.

Ten stories. Sixty-nine scenarios. One very locally-hosted Otter. Next:
per-story QA and the release pipeline John's been building upstream.
