# Membrane.Element.Base

Module defining behaviour common to all elements.

When used declares behaviour implementation, provides default callback definitions
and imports macros.

# Elements

Elements are units that produce, process or consume data. They can be linked
with `Membrane.Pipeline`, and thus form a pipeline able to perform complex data
processing. Each element defines a set of pads, through which it can be linked
with other elements. During playback, pads can either send (output pads) or
receive (input pads) data. For more information on pads, see
`Membrane.Pad`.

Note: This module (`Membrane.Element.Base`) should not be `use`d directly.

To implement an element, one of the following base modules (`Membrane.Source`,
`Membrane.Filter`, `Membrane.Endpoint` or `Membrane.Sink`)
has to be `use`d, depending on the element type:
- source, producing buffers (contain only output pads),
- filter, processing buffers (contain both input and output pads),
- endpoint, producing and consuming buffers (contain both input and output pads),
- sink, consuming buffers (contain only input pads).
For more information on each element type, check documentation for appropriate
base module.

## def_options/1

A callback for constructing struct with values. Will be defined by `def_options/1` if used.

See `defstruct/1` for a more in-depth description.

## def_clock/1

Defines that element exports a clock to pipeline.

Exporting clock allows pipeline to choose it as the pipeline clock, enabling other
elements to synchronize with it. Element's clock is accessible via `clock` field,
while pipeline's one - via `parent_clock` field in callback contexts. Both of
them can be used for starting timers.

## __using__/1

Brings common stuff needed to implement an element. Used by
`Membrane.Source.__using__/1`, `Membrane.Filter.__using__/1`,
`Membrane.Endpoint.__using__/1` and `Membrane.Sink.__using__/1`.

Options:
  - `:bring_pad?` - if true (default) requires and aliases `Membrane.Pad`
  - `:flow_control_hints?` - if true (default) generates compile-time warnings     if the number, direction, and type of flow control of pads are likely to cause unintended     behaviours.