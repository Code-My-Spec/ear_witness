# Membrane.Core.Bin



## start_link/1

Starts the Bin based on given module and links it to the current
process.

Bin options are passed to module's `c:Membrane.Bin.handle_init/2` callback.

Process options are internally passed to `GenServer.start_link/3`.

Returns the same values as `GenServer.start_link/3`.

## start/1

Works similarly to `start_link/3`, but does not link to the current process.