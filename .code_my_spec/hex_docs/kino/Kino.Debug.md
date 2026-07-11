# Kino.Debug



## dbg/4

Custom backend for `Kernel.dbg/2`.

The custom backend provides a more interactive user interface for
`Kernel.dbg/2` calls in certain cases, such as call pipelines. It
falls back to the default backend otherwise.

## register_dbg_handler!/1

Registers caller as the process handling the given dbg call.

## lookup_dbg_handler/1

Looks up a process handling the given dbg call.