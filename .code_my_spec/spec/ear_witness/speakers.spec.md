# EarWitness.Speakers

Who said what — on-device diarization (VAD + speaker-embedding ONNX models via ortex) and speaker identity: clustering voice signatures within a recording and matching them across the library so recurring voices resolve to named people.

## Type

context

## Dependencies

- EarWitness.Models
- EarWitness.Transcription
- EarWitness.Recordings (looks up a transcript's recording to hand its
  audio file to `EarWitness.Speakers.Diarizer`)
