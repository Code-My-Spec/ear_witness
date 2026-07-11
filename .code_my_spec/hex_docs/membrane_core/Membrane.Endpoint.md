# Membrane.Endpoint

Module defining behaviour for endpoints - elements consuming and producing data.

Behaviours for endpoints are specified, besides this place, in modules
`Membrane.Element.Base`,
`Membrane.Element.WithOutputPads`,
and `Membrane.Element.WithInputPads`.

Endpoint can have both input and output pads. Job of usual endpoint is both, to
receive some data on input pads and consume it (write to a soundcard, send through
TCP etc.) and to produce some data (read from soundcard, download through HTTP,
etc.) and send on output pads. If the pad has the flow control set to
`:manual`, then endpoint is also responsible for receiving demands on the output
pad and requesting them on the input pad (for more details, see
`c:Membrane.Element.WithOutputPads.handle_demand/5` callback).
Endpoints, like all elements, can of course have multiple pads if needed to
provide more complex solutions.

Although Endpoints may seem similair to [Filters](`m:Membrane.Filter`) - they both have
input and output pads - there are some important differences. While Filters can
be thought as parts of a Pipeline that 
take in data, process it in some way, and then pass it along, Endpoints create 
"holes" in the pipeline. They behave more like a [Sink](`m:Membrane.Sink`) and a 
[Source](`m:Membrane.Source`) combined in a single element - media they consume
and produce are parts of different streams. 

For instance, while a typical Filter would only modify
the input stream and then forward it, a typical Endpoint would consume the input stream
(e.g. send it to some external receiver) and produce a completely separate output stream 
(e.g. receive it from some external sender).

The main consequence of this is the fact that 
they separate the flow control of the pipeline ahead of them and behind them, 
as their input pads behave like those of a Sink, and their output pads behave
like those of a Source: 
  * A Filter can have `:flow_control` set to `:auto` on its output pads, an Endpoint cannot - just like a Source.
  * A Filter cannot return `:redemand` action in `handle_demand` callback, an Endpoint can - just like a Source.

## __using__/1

Brings all the stuff necessary to implement a endpoint element.

Options:
  - `:bring_pad?` - if true (default) requires and aliases `Membrane.Pad`
  - `:flow_control_hints?` - if true (default) generates compile-time warnings     if the number, direction, and type of flow control of pads are likely to cause unintended     behaviours.