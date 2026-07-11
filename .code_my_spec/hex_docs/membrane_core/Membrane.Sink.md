# Membrane.Sink

Module defining behaviour for sinks - elements consuming data.

Behaviours for sinks are specified, besides this place, in modules
`Membrane.Element.Base`,
and `Membrane.Element.WithInputPads`.

Sink elements can define only input pads. Job of a usual sink is to receive some
data on such pad and consume it (write to a soundcard, send through TCP etc.).
If the pad has the flow control set to `:manual`, then element is also responsible
for requesting demands when it is able and willing to consume data (for more details,
see `t:Membrane.Element.Action.demand/0`). Sinks, like all elements, can of course
have multiple pads if needed to provide more complex solutions.

## __using__/1

Brings all the stuff necessary to implement a sink element.

Options:
  - `:bring_pad?` - if true (default) requires and aliases `Membrane.Pad`
  - `:flow_control_hints?` - if true (default) generates compile-time warnings     if the number, direction, and type of flow control of pads are likely to cause unintended     behaviours.