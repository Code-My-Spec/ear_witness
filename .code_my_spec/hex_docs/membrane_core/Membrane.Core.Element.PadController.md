# Membrane.Core.Element.PadController



## handle_link/5

Verifies linked pad, initializes it's data.

## handle_unlink/2

Handles situation where pad has been unlinked (e.g. when connected element has been removed from pipeline)

Removes pad data.
Signals an EoS (via handle_event) to the element if unlinked pad was an input.
Executes `handle_pad_removed` callback if the pad was dynamic.
Note: it also flushes all buffers from PlaybackBuffer.

## generate_eos_if_needed/2

Generates end of stream on the given input pad if it hasn't been generated yet
and playback is `playing`.