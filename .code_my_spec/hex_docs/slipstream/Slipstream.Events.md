# Slipstream.Events



## map/2

Maps a message from the remote websocket server to an internally known
Slipstream event

The connection state may need to be taken into consideration. It holds
information about the `ref` fields on messages and whether or not they belong
to joins or leaves.

`server_message` is either a `%Slipstream.Message{}` or `:ping` or `:pong`.
`connection_state` is the GenServer state of the connection process.