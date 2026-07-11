# Slipstream.TelemetryHelper



## begin_connect/2

Emits a start event for an attempt to connect

Emitted in cases of a client using `Slipstream.connect/2`,
`Slipstream.connect!/2` or `Slipstream.reconnect/1`.

## conclude_connect/2

Emits a stop event for an attempt to connect

Emitted when the connection process tells the client that it has successfully
connected with a `Slipstream.Events.ChannelConnected` event.

## begin_join/3

Emits a start event for an attempt to join

Emitted in cases of a client using `Slipstream.join/3` or
`Slipstream.rejoin/3`.

## conclude_join/2

Emits a stop event for an attempt to join

Emitted when the connection process tells the client that it has successfully
connected with a `Slipstream.Events.TopicJoinSucceeded` event.

## wrap_dispatch/4

Wraps a callback dispatch to a Slipstream client module