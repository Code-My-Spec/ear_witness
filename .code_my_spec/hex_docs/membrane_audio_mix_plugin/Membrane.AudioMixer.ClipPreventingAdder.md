# Membrane.AudioMixer.ClipPreventingAdder

Module responsible for mixing audio tracks (all in the same format, with the same number of
channels and sample rate). The result is a single track in the format mixed tracks are encoded in.
If overflow happens during mixing, a wave will be scaled down to the max sample value.

Description of the algorithm:
  - Start with an empty queue
  - Enqueue merged values while the sign of the values remains the same
  - If the sign of values changes or adder is flushed:
    - If none of the values overflows limits of the format, convert the queued values
      to binary samples and return them
    - Otherwise, scale down the queued values, so the peak of the wave will become
      maximal (minimal) allowed value, then convert it to binary samples and return
      them.