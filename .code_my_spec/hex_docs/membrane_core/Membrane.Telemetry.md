# Membrane.Telemetry

Defines basic telemetry event types used by Membrane's Core.

Membrane uses [Telemetry Package](https://hex.pm/packages/telemetry) for instrumentation and does not store or save any measurements by itself.

It is user's responsibility to use some sort of event handler and metric reporter
that will be attached to `:telemetry` package to process generated measurements.

## Instrumentation
The following telemetric events are published by Membrane's Core components:

  * `[:membrane, :element | :bin | :pipeline, callback, :start | :stop | :exception]` -
  where `callback` is any possible `handle_*` function defined for a component. Metadata
  passed to these events is `t:callback_span_metadata/0`.
    * `:start` - when the components begins callback's execution
    * `:stop` - when the components finishes callback's execution
    * `:exception` - when the component crashes during callback's execution

  * `[:membrane, :datapoint, datapoint_type]` -
  where datapoint_type is any of the available datapoint types (see below).
  Metadata passed to these events is `t:datapoint_metadata/0`.

## Enabling specific datapoints
A lot of datapoints can happen hundreds times per second such as registering that a buffer has been sent/processed.

This behaviour can come with a great performance penalties but may be helpful for certain discoveries. To avoid any runtime overhead
when the reporting is not necessary all spans/datapoints are hidden behind a compile-time feature flags.
To enable a particular measurement one must recompile membrane core with the following config put inside
user's application `config.exs` file:

```
    config :membrane_core,
      telemetry_flags: [
        tracked_callbacks: [
          bin: [:handle_setup, ...] | :all,
          element: [:handle_init, ...] | :all,
          pipeline: [:handle_init, ...] | :all
        ],
      datapoints: [:buffer, ...] | :all
      ]
  ```

Datapoint metrics are to be deprecated in the future (2.0) in favor of spans. They are still available for now.

Available datapoints are:
* `:link` - reports the number of links created in the pipeline
* `:buffer` - number of buffers being sent from a particular element
* `:queue_len` - number of messages in element's message queue during GenServer's `handle_info` invocation
* `:stream_format` - indicates that given element has received new stream format, value always equals '1'
* `:event` - indicates that given element has received a new event, value always equals '1'
* `:store` - reports the current size of a input buffer when storing a new buffer
* `:take` - reports the number of buffers taken from the input buffer