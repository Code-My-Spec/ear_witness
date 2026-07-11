# Membrane.Element.PadData

Struct describing current pad state.

The public fields are:
  - `:availability` - see `t:Membrane.Pad.availability/0`
  - `:stream_format` - the most recent `t:Membrane.StreamFormat.t/0` that have been sent (output) or received (input)
    on the pad. May be `nil` if not yet set.
  - `:direction` - see `t:Membrane.Pad.direction/0`
  - `:end_of_stream?` - flag determining whether the stream processing via the pad has been finished
  - `:flow_control` - see `t:Membrane.Pad.flow_control/0`.
  - `:name` - see `t:Membrane.Pad.name/0`. Do not mistake with `:ref`
  - `:options` - options passed in `Membrane.ParentSpec` when linking pad
  - `:ref` - see `t:Membrane.Pad.ref/0`
  - `:start_of_stream?` - flag determining whether the stream processing via the pad has been started
  - `auto_demand_paused?` - flag determining if auto-demanding on the pad is paused or no
  - `max_instances` - specifies maximal possible number of instances of a dynamic pad that can exist within single element. Equals `nil` for pads with `availability: :always`.

Other fields in the struct ARE NOT PART OF THE PUBLIC API and should not be
accessed or relied on.