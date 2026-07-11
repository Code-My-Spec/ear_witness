# Membrane.Filter

Module defining behaviour for filters - elements processing data.

Behaviours for filters are specified, besides this place, in modules
`Membrane.Element.Base`,
`Membrane.Element.WithOutputPads`,
and `Membrane.Element.WithInputPads`.

Filters can have both input and output pads. Job of a usual filter is to
receive some data on a input pad, process the data and send it through the
output pad. If the pad has the flow control set to `:manual`, then filter
is also responsible for receiving demands on the output pad and requesting
them on the input pad (for more details, see
`c:Membrane.Element.WithOutputPads.handle_demand/5` callback).
Filters, like all elements, can of course have multiple pads if needed to
provide more complex solutions.

## __using__/1

Brings all the stuff necessary to implement a filter element.

Options:
  - `:bring_pad?` - if true (default) requires and aliases `Membrane.Pad`
  - `:flow_control_hints?` - if true (default) generates compile-time warnings     if the number, direction, and type of flow control of pads are likely to cause unintended     behaviours.