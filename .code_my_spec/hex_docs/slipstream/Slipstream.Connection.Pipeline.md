# Slipstream.Connection.Pipeline



## put_event/3

Adds an event to be emitted

Note that this will not be the actual event to-be-sent, but an atom used to
build the event in the `build_events/1` phase of the pipeline

## put_return/2

Declares the return value of the pipeline

This value will be given to the GenServer callback that invoked