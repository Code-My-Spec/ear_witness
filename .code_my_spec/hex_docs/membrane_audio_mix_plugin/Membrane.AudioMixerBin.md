# Membrane.AudioMixerBin

Bin element distributing a mixing job between multiple `Membrane.AudioMixer` elements.

A tree of AudioMixers is created according to `max_inputs_per_node` parameter:
- if number of input tracks is smaller than `max_inputs_per_node`, only one AudioMixer element is created for the entire job
- if there are more input tracks than `max_inputs_per_node`, there are created enough mixers so that each mixer has at most
`max_inputs_per_node` inputs - outputs from those mixers are then mixed again following the same rules -
another level of mixers is created having enough mixers so that each mixer on this level has at most
`max_inputs_per_node` inputs (those are now the outputs of the previous level mixers).
Levels are created until only one mixer in the level is needed - output from this mixer is the final mixed track.

Bin allows for specifying options for `Membrane.AudioMixer`, which are applied for all AudioMixers.

Recommended to use in case of mixing jobs with many inputs.

A number of inputs to the bin must be specified in the `number_of_inputs` option.

## gen_mixing_spec/3

Generates a spec for a single mixer or a tree of mixers.

Levels of the tree will be 0-indexed with tree root being level 0
For a bottom level of mixing tree (leaves of the tree) links generator will be used to generate links between inputs and mixers.