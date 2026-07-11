# Plug.Cowboy.Drainer

Process to drain cowboy connections at shutdown.

When starting `Plug.Cowboy` in a supervision tree, it will create a listener that receives
requests and creates a connection process to handle that request. During shutdown, a
`Plug.Cowboy` process will immediately exit, closing the listener and any open connections
that are still being served. However, in most cases, it is desirable to allow connections
to complete before shutting down.

This module provides a process that during shutdown will close listeners and wait
for connections to complete. It should be placed after other supervised processes that
handle cowboy connections.

## Options

The following options can be given to the child spec:

  * `:refs` - A list of refs to drain. `:all` is also supported and will drain all cowboy
    listeners, including those started by means other than `Plug.Cowboy`.

  * `:id` - The ID for the process.
    Defaults to `Plug.Cowboy.Drainer`.

  * `:shutdown` - How long to wait for connections to drain.
    Defaults to 5000ms.

  * `:check_interval` - How frequently to check if a listener's
    connections have been drained. Defaults to 1000ms.

## Examples

    # In your application
    def start(_type, _args) do
      children = [
        {Plug.Cowboy, scheme: :http, plug: MyApp, options: [port: 4040]},
        {Plug.Cowboy, scheme: :https, plug: MyApp, options: [port: 4041]},
        {Plug.Cowboy.Drainer, refs: [MyApp.HTTP, MyApp.HTTPS]}
      ]

      opts = [strategy: :one_for_one, name: MyApp.Supervisor]
      Supervisor.start_link(children, opts)
    end