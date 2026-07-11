# Membrane.Core.Element



## start_link/1

Starts process for element of given module, initialized with given options and
links it to the current process in the supervision tree.

Calls `GenServer.start_link/3` underneath.

## start/1

Works similarly to `start_link/3`, but does not link to the current process.