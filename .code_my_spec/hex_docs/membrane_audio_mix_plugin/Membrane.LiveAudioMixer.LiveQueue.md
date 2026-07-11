# Membrane.LiveAudioMixer.LiveQueue

There are a lot of problems that the mixer can encounter while processing live audio streams:
* packet loss resulting in small stream discontinuity
* connection issues resulting in  complete lack of data
* the need for enforcing max latency on the stream - packets that come too late have to be dropped

The LiveQueue tackles all those problems.
It has an independent queue for each stream.
Every gap caused by late or dropped packets are filled with silence.
If there is a need for more audio than there is in a queue, the missing part will also be filled with silence.

## remove_queue/2

Removes queue from a live queue.

If the queue is empty, it will be removed right away.
Otherwise, it will be marked as `draining` and will be removed when it will get empty.

## add_buffer/3

Adds to a specific queue.

When a buffer is too old it will be dropped
When a part of a buffer is too old, only the part that is "fresh" will be added.
When a whole buffer is "fresh", the whole buffer will be added.
All the wholes between audio packets will be filled with silence.

The state of the buffer, whether it's too old or not, is based on LiveQueue's `current_time`.