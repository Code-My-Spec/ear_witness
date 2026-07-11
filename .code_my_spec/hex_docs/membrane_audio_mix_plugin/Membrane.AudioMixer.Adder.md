# Membrane.AudioMixer.Adder

Module responsible for mixing audio tracks (all in the same format, with the same number of
channels and sample rate). The result is a single track in the format mixed tracks are encoded in.
If overflow happens during mixing, it is being clipped to the max value of sample in this format.