# Membrane.RawAudioParser

This element is responsible for parsing audio in RawAudio format.
The Parser ensures that output buffers have whole samples.

By default, the parser doesn't ensure that each output buffer holds
the same number of samples, it only re-aligns buffers to whole samples.
When `chunk_duration` is set, the parser additionally re-chunks the stream,
so that every output buffer carries exactly `chunk_duration` worth of audio.