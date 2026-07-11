# Membrane.AudioMixer

This element performs audio mixing.

Audio format can be set as an element option or received through stream_format from input pads. All
received stream_format have to be identical and match ones in element option (if that option is
different from `nil`).

Input pads can have offset - it tells how much silence should be added before first sample
from that pad. Offset has to be positive.

Mixer mixes only raw audio (PCM), so some parser may be needed to precede it in pipeline.