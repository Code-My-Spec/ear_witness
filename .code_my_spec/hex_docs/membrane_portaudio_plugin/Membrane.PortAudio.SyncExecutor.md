# Membrane.PortAudio.SyncExecutor

A GenServer executing actions received by `GenServer.call/3` or `send/2`.

Some PortAudio operations (such as starting and stopping stream) must not be
executed concurrently, so they are received and executed here, synchronously.

## apply/4

A simple wrapper around `GenServer.call/3.`