# Slipstream.Connection.State



## new/2

Creates a new State data structure

The life-cycle of a `Slipstream.Connection` matches that of a websocket
connection between client and remote websocket server, so a new `State`
data structure represents a new connection (and therefore generates a new
connection_id for telemetry purposes).

## next_ref/1

Gets the next ref and increments the ref counter in state

The `ref` passed between a client and phoenix server is a marker which
can be used to link pushes to their replies. E.g. a heartbeat message from
the client will include a ref which will match the associated heartbeat
reply from the server, when the heartbeat is successful.

Refs are simply strings of incrementing integers.

## reset_heartbeat/1

Resets the heartbeat ref to nil

This is used to clear out a pending heartbeat. If the
`Slipstream.Commands.SendHeartbeat` command is received and the heartbeat_ref
in state is nil, that means we have not received a reply to our heartbeat
request and that the server is potentially stuck or otherwise not responding.

## join_ref?/2

Detects if a ref is one used to join a topic

## leave_ref?/2

Detects if a ref was used to request a topic leave