# Membrane.Bin.PadData

Struct describing current pad state.

The public fields are:
  - `:availability` - see `t:Membrane.Pad.availability/0`
  - `:direction` - see `t:Membrane.Pad.direction/0`
  - `:name` - see `t:Membrane.Pad.name/0`. Do not mistake with `:ref`
  - `:options` - options passed in `Membrane.ChildrenSpec` when linking pad
  - `:ref` - see `t:Membrane.Pad.ref/0`
  - `max_instances` - specifies maximal possible number of instances of a dynamic pad that can exist within single element. Equals `nil` for pads with `availability: :always`.

Other fields in the struct ARE NOT PART OF THE PUBLIC API and should not be
accessed or relied on.