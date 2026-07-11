# Bundlex.CNode

Utilities to ease interaction with Bundlex-based CNodes, so they can be treated
more like Elixir processes / `GenServer`s.

## start_link/2

Spawns and connects to CNode `cnode_name` from application `app`.

The CNode is passed the following command line arguments:
- host name,
- alive name,
- node name,
- creation number.

After CNode startup, these parameters should be passed to
[`ei_connect_xinit`](http://erlang.org/doc/man/ei_connect.html#ei_connect_xinit)
function, and CNode should be published and await connection. Once the CNode is
published, it should print a line starting with `ready` to the standard output
**and flush the standard output** to avoid the line being buffered.

Under the hood, this function starts an associated server, which is responsible
for monitoring the CNode and monitoring calling process to be able to do proper
cleanup upon a crash. On startup, the server does the following:
1. Makes current node distributed if it is not done yet (see `Node.start/2`).
1. Assigns CNode a unique name.
1. Starts CNode OS process using `Port.open/2`.
1. Waits (at most 5 seconds) until a line `ready` is printed out
(this line is captured and not forwarded to the stdout).
1. Connects to the CNode.

The erlang cookie is passed using the BUNDLEX_ERLANG_COOKIE an environment variable.

## start/2

Works the same way as `start_link/2`, but does not link to CNode's associated
server.

## stop/1

Disconnects from CNode.

It is the responsibility of the CNode to exit upon connection loss.

## monitor/1

Starts monitoring CNode from the calling process.

## call/3

Makes a synchronous call to CNode and waits for its reply.

The CNode is supposed to send back a `{cnode, response}` tuple where `cnode`
is the node name of CNode. If the response doesn't come in within `timeout`,
error is raised.

Messages are exchanged directly (without interacting with CNode's associated
server).

## send/2

Sends a message to cnode.

The message is exchanged directly (without interacting with CNode's associated
server).