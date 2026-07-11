# Membrane.FilterAggregator

An element allowing to aggregate many filters within one Elixir process.

Warning: This element is still in experimental phase

This element supports only filters with one input and one output
with following restrictions:
* not using timers
* not relying on received messages
* not expecting any events coming from downstream elements
* their pads have to be named `:input` and `:output`
* their pads cannot use manual demands
* the first filter must make demands in buffers