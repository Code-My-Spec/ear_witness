# Unifex.CNode

Wraps Bundlex.CNode functionalities to support Unifex-specific CNode behaviours

## start_link/1

Spawns and connects to CNode `cnode_name`.

For details, see `Bundlex.CNode.start_link/2`.

## start/1

Works the same way as `start_link/1`, but does not link to CNode's associated
server.

## start_link/2

Spawns and connects to CNode `cnode_name` from application `app`.

For details, see `Bundlex.CNode.start_link/2`.

## start/2

Works the same way as `start_link/2`, but does not link to CNode's associated
server.

## stop/1

Disconnects from CNode.

## monitor/1

Starts monitoring CNode from the calling process.

## call/4

Makes a synchronous call to CNode and waits for its reply.

If the response doesn't come in within `timeout`, error is raised.
Messages are exchanged directly (without interacting with CNode's associated
server).