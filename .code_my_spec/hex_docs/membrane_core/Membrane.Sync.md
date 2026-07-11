# Membrane.Sync

Sync allows to synchronize multiple processes, so that they could perform their
jobs at the same time.

The main purpose for Sync is to synchronize multiple streams within a pipeline.
The flow of usage goes as follows:
- A Sync process is started.
- Processes register themselves (or are registered) in the Sync, using
`register/2`. Registered processes are not being synchronized till the Sync
becomes active (see the next step). Each registered process is monitored and
automatically unregistered upon exit. Sync can be setup to exit when all the
registered processes exit by passing the `empty_exit?` option to `start_link/2`.
- When all processes that need to be registered are registered, the Sync can
be activated with `activate/1` function. This disables registration and enables
synchronization.
- Once a process needs to sync, it invokes `sync/2`, which results in blocking
until all the registered processes invoke `sync/2`. This works only when the Sync
is active - otherwise calling `sync/2` returns immediately.
- Once all the ready processes invoke `sync/2`, the calls return, and they become
registered again.
- When synchronization needs to be turned off, the Sync should be deactivated
with `deactivate/2`. This disables synchronization and enables registration again.
All the calls to `sync/2` return immediately.

If a process designed to work with Sync should not be synced, `no_sync/0` should
be used. Then all calls to `sync/2` return immediately.

## start_link/2

Starts a Sync process linked to the current process.

## Options
- :empty_exit? - if true, Sync automatically exits when all the registered
  processes exit; defaults to false

## no_sync/0

Returns a Sync that always returns immediately when calling `sync/2` on it.