# Kino.JS.Live



## __using__/1

Invoked when the server is about to exit.

See `c:GenServer.terminate/2` for more details.

## new/3

Instantiates a live JavaScript kino defined by `module`.

The given `init_arg` is passed to the `init/2` callback when
the underlying kino process is started.

## Options

  * `:export` - a function called to export the given kino to Markdown.
    This works the same as `Kino.JS.new/3`, except the function
    receives `t:Kino.JS.Live.Context.t/0` as an argument

## cast/2

Sends an asynchronous request to the kino server.

See `GenServer.cast/2` for more details.

## call/3

Makes a synchronous call to the kino server and waits
for its reply.

See `GenServer.call/3` for more details.

## reply/2

Replies to the kino server.

This function can be used to explicitly send a reply to the kino server
that called `call/3` when the reply cannot be specified in the return
value of `handle_call/3`.

See `GenServer.reply/2` for more details.

## monitor/1

Starts monitoring the kino server from the calling process.

Refer to `Process.monitor/1` for more details.