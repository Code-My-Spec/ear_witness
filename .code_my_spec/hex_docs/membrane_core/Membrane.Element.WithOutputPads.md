# Membrane.Element.WithOutputPads

Module defining behaviour for source and filter elements.

When used declares behaviour implementation, provides default callback definitions
and imports macros.

For more information on implementing elements, see `Membrane.Element.Base`.

## def_output_pad/2

Callback called when buffers should be emitted by a source, filter or endpoint.

It is called only for output pads in the `:manual` flow control mode, as in their case demand
is triggered by the input pad of the subsequent element.

In sources and endpoint, appropriate amount of data should be sent here.

In filters, this callback should usually return `:demand` action with
size sufficient for supplying incoming demand. This will result in calling
`c:Membrane.WithInputPads.handle_buffer/4`, which is to supply
the demand.

If a source or an endpoint is unable to produce enough buffers, or a filter
underestimated returned demand, the `:redemand` action should be used (see
`t:Membrane.Element.Action.redemand/0`).

Context passed to this callback contains additional field `:incoming_demand`.