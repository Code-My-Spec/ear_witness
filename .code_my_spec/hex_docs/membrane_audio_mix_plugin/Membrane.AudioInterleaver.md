# Membrane.AudioInterleaver

Element responsible for interleaving several mono audio streams into single interleaved stream.
All input streams should be in the same raw audio format, defined by `input_stream_format` option.

Channels are interleaved in order given in `order` option - currently required, no default available.

Each input pad should be identified with your custom id (using `via_in(Pad.ref(:input, your_example_id)` )