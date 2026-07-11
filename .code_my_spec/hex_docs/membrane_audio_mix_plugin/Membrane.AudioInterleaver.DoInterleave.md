# Membrane.AudioInterleaver.DoInterleave

Module responsible for interleaving audio tracks (all in the same format, with 1
channel) in a given order.

## interleave/4

Order queues according to `order`, take `bytes_per_channel` from each queue
(all queues must be at least `bytes_per_channel` long),
and interleave them.