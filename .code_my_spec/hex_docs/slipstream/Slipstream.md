# Slipstream

A websocket client for Phoenix channels

Slipstream is a websocket client for connection to `Phoenix.Channel`s.
Slipstream is a bit different from existing websocket implementations in that:

- it's backed by `Mint.WebSocket`
- it has an `await_*` interface for performing actions synchronously
- smart retry strategies for reconnection and rejoining work out-of-the-box
- a testing framework for clients
- high-level and low-level instrumentation with `:telemetry`

## Basic Usage

The intended use for Slipstream is to write asynchronous, callback-oriented
GenServer-like modules that define socket clients. This approach makes it
easy to write socket clients that resemble state-machines. A minimalistic
example usage might be like so:

    defmodule MyApp.MySocketClient do
      @moduledoc """
      A socket client for connecting to that other Phoenix server

      Periodically sends pings and asks the other server for its metrics.
      """

      use Slipstream,
        restart: :temporary

      require Logger

      @topic "backend-service:money-server"

      def start_link(args) do
        Slipstream.start_link(__MODULE__, args, name: __MODULE__)
      end

      @impl Slipstream
      def init(config) do
        {:ok, connect!(config), {:continue, :start_ping}}
      end

      @impl Slipstream
      def handle_continue(:start_ping, socket) do
        timer = :timer.send_interval(1000, self(), :request_metrics)

        {:noreply, assign(socket, :ping_timer, timer)}
      end

      @impl Slipstream
      def handle_connect(socket) do
        {:ok, join(socket, @topic)}
      end

      @impl Slipstream
      def handle_join(@topic, _join_response, socket) do
        # an asynchronous push with no reply:
        push(socket, @topic, "hello", %{})

        {:ok, socket}
      end

      @impl Slipstream
      def handle_info(:request_metrics, socket) do
        # we will asynchronously receive a reply and handle it in the
        # handle_reply/3 implementation below
        {:ok, ref} = push(socket, @topic, "get_metrics", %{format: "json"})

        {:noreply, assign(socket, :metrics_request, ref)}
      end

      @impl Slipstream
      def handle_reply(ref, metrics, socket) do
        if ref == socket.assigns.metrics_request do
          :ok = MyApp.MetricsPublisher.publish(metrics)
        end

        {:ok, socket}
      end

      @impl Slipstream
      def handle_message(@topic, event, message, socket) do
        Logger.error(
          "Was not expecting a push from the server. Heard: " <>
            inspect({@topic, event, message})
        )

        {:ok, socket}
      end

      @impl Slipstream
      def handle_disconnect(_reason, socket) do
        :timer.cancel(socket.assigns.ping_timer)

        {:stop, :normal, socket}
      end
    end

## Synchronicity

Slipstream is designed to work asynchronously by default. Requests such
as `connect/2`, `join/3`, and `push/4` are asynchronous requests. When
the remote server replies, the associated callback will be invoked
(`c:handle_connect/1`, `c:handle_join/3`, and `c:handle_reply/3` in cases
of success, respectively). For all of these operations, though, you may
await the outcome of the asynchronous request with `await_*` functions. E.g.

    iex> {:ok, ref} = push(socket, "room:lobby", "msg:new", %{user: 1, msg: "foo"})
    iex> {:ok, %{"created" => true}} = await_reply(ref)

Note that all `await_*` functions must be called from the slipstream process
that emitted the request, or else they will timeout.

While Slipstream provides a rich toolset for synchronicity, the asynchronous,
callback-based workflow is recommended.

## GenServer operations

Note that Slipstream is in many ways a simple wrapper around a GenServer.
As such, all GenServer functionality is possible with Slipstream clients,
such as `Kernel.send/2` or `GenServer.call/3`. For example, assume you have
a slipstream client written like so:

    defmodule MyClient do
      use Slipstream

      require Logger

      def start_link(args) do
        Slipstream.start_link(__MODULE__, args, name: __MODULE__)
      end

      @impl Slipstream
      def init(config), do: connect(config)

      @impl Slipstream
      def handle_cast(:ping, socket) do
        Logger.info("pong")

        {:noreply, socket}
      end

      @impl Slipstream
      def handle_info(:hello, socket) do
        Logger.info("hello")

        {:noreply, socket}
      end

      @impl Slipstream
      def handle_call(:foo, _from, socket) do
        {:reply, {:ok, :bar}, socket}
      end

      ..
    end

This `MyClient` client is a GenServer, so the following are valid ways to
interact with `MyClient`:

    iex> GenServer.cast(MyClient, :ping)
    [info] pong
    :ok
    iex> MyClient |> GenServer.whereis |> send(:hello)
    [info] hello
    :hello
    iex> GenServer.call(MyClient, :foo)
    {:ok, :bar}

## Retry Mechanisms

There are two levels at which retry logic may be needed: for maintaining a
websocket connection and for retrying messages to which the server replies
with an error or does not reply.
Slipstream does not implement message retries because the needs of applications
will vary; if you need retries, you can build the logic you need using
`push/4`, `c:handle_reply/3`, and something like `Process.send_after/4`.

To maintain a websocket connection, Slipstream emulates the official
`phoenix.js` package with its reconnection and re-join features.
`Slipstream.Configuration` allows configuration of the back-off times with
the `:reconnect_after_msec` and `:rejoin_after_msec` lists, respectively.

To take advantage of these built-in mechanisms, a client must be written
in the asynchronous GenServer-like manner and must use the `reconnect/1` and
`rejoin/3` functions in its `c:Slipstream.handle_disconnect/2` and
`c:Slipstream.handle_topic_close/3` callbacks, respectively. Note that the
default implementation of these callbacks invokes these functions, so a client
which does not explicitly define these callbacks will retry connection and
joins.

Take care to handle the `:left` case of `c:Slipstream.handle_topic_close/3`.
In the case that a client attempts to leave a topic with `leave/2`, the
callback will be invoked with a `reason` of `:left`. The default
implementation of `c:Slipstream.handle_topic_close/3` makes this distinction
and simply no-ops on channel leaves.

    defmodule MyClientWithRetry do
      use Slipstream

      def start_link(config) do
        Slipstream.start_link(__MODULE__, config, name: __MODULE__)
      end

      @impl Slipstream
      def init(config), do: connect(config)

      @impl Slipstream
      def handle_connect(socket) do
        {:ok, join(socket, "rooms:lobby", %{user_id: 1})}
      end

      @impl Slipstream
      def handle_disconnect(_reason, socket) do
        case reconnect(socket) do
          {:ok, socket} -> {:ok, socket}
          {:error, reason} -> {:stop, reason, socket}
        end
      end

      @impl Slipstream
      def handle_topic_close(topic, _reason, socket) do
        rejoin(socket, topic)
      end
    end

## connect/2

Requests connection to the remote endpoint

`opts` are passed to `Slipstream.Configuration.validate/1` before sending.

Note that this request for connection is asynchronous. A return value of
`{:ok, socket}` does not mean that a connection has successfully been
established.

## Examples

    {:ok, socket} = connect(uri: "ws://localhost:4000/socket/websocket")

## connect!/2

Same as `connect/2` but raises on configuration validation error

Note that `connect!/2` will not necessarily raise an error on failure to
connect. The `!` only pertains to the potential for raising when the
configuration is invalid.

## reconnect/1

Request reconnection given the last-used connection configuration

Note that when `reconnect/1` is used to re-connect instead of `connect/2`
(or `connect!/2`), the slipstream process will attempt to reconnect with
a retry mechanism with backoff. The process will wait an interval between
reconnection attempts following the list of milliseconds provided in the
`:reconnect_after_msec` key of configuration passed to `connect/2` (or
`connect!/2`).

The `c:handle_disconnect/2` callback will be invoked for each
failure to re-connect, however, so an implementation of that callback which
will simply retry with backoff can be achieved like so:

    @impl Slipstream
    def handle_disconnect(_reason, socket) do
      case reconnect(socket) do
        {:ok, socket} -> {:ok, socket}
        {:error, reason} -> {:stop, reason, socket}
      end
    end

`reconnect/1` may return an `:error` tuple in the case that the socket passed
does not contain any connection information (which is added to the socket
with `connect/2` or `connect!/2`), or if the socket is currently connected.
For a `reconnect/1` call without configuration, the return pattern is
`{:error, :no_config}`, and for a socket that is already connected, the
pattern is `{:error, :connected}`.

A reconnect may be awaited with `await_connect/2`.

## join/3

Requests that a topic be joined in the current connection

Multiple topics may be joined by one Slipstream client, but each topic
may only be joined once. Despite this, `join/3` may be called on the same
topic multiple times, but the result will be idempotent. The client will
not request to join unless it has not yet joined that topic. In cases where
you wish to begin a new session with a topic, you must first `leave/2` and
then `join/3` again.

The request to join will not error-out if the client is not connected to a
remote server. In that case, the `join/3` function will act as a no-op.

A join can be awaited in a blocking fashion with `await_join/3`.

## Examples

    @impl Slipstream
    def handle_connect(socket) do
      {:ok, join(socket, "rooms:lobby", %{user: 1})}
    end

## rejoin/3

Requests that the specified topic be joined again

If `params` is not provided, the previously used value will be sent.

In the case that the specified topic has not been joined before, `rejoin/3`
will return `{:error, :never_joined}`.

Note that a rejoin may be awaited with `await_join/3`.

## Dealing with crashes

When attempting to re-join a disconnected topic with `rejoin/3`, the
Slipstream process will attempt to use backoff governed by the
`:rejoin_after_msec` list in configuration passed to `connect/2` (or
`connect!/2`).

The `c:handle_topic_close/3` callback will be invoked with
the for each crash, however, so a minimal implementation of that callback
which achieves the backoff retry is like so:

## Examples

    @impl Slipstream
    def handle_topic_close(topic, _reason, socket) do
      {:ok, _socket} = rejoin(socket, topic)
    end

## leave/2

Requests that the given topic be left

Note that like joining, leaving is an asynchronous request and can be awaited
with `await_leave/3`.

Also similar to `join/3`, `leave/2` is idempotent and will not raise an error
if the provided topic is not currently joined.

## Examples

    iex> {:ok, socket} = leave(socket, "room:lobby") |> await_leave("rooms:lobby")
    iex> join(socket, "rooms:specific")

## push/5

Requests that a message be pushed on the websocket connection

A channel has the ability to reply directly to a message, but this reply
is asynchronous. Handle replies using the `c:handle_reply/3`
callback or by awaiting them synchronously with `await_reply/2`.

Although this request to the remote server is asynchronous, the call to the
transport process to transmit the push is synchronous and will exert
back-pressure on calls to `push/4`, as `push/4` blocks until the message
has been written to the network socket by the transport.

An `{:ok, ref}` return from `push/4` does not mean the message has been
delivered to the phoenix channel or even that it has been sent on the
network; it only means that the connection was alive as of the most recent
heartbeat and that the given data was therefore written to the network socket
using `:gen_tcp.send/2` or `:ssl.send/2`.

The only way to confirm that a message was delivered to the phoenix channel
is if the channel replies to the message. In order to link push requests to
their replies, store the `ref` string returned from the call to `push/4` and
match on it in `c:handle_reply/3`.

If you are pushing especially large messages, you may need to adjust the
`timeout` argument so that the GenServer call does not exit with `:timeout`.
The default value is `5_000` msec (5 seconds).

## Examples

    @impl Slipstream
    def handle_join(:success, _response, state) do
      {:ok, hello_request} = push(socket, "rooms:lobby", "new:msg", %{user: 1, body: "hello"})

      {:ok, Map.put(state, :hello_request, hello_request)}
    end

    @impl Slipstream
    def handle_reply(ref, reply, %{hello_request: ref} = state) do
      IO.inspect(reply, label: "nice, a response.")

      {:ok, state}
    end

## push!/4

Pushes, raising if the topic is not joined or if the channel is dead

Same as `push/4`, but raises in cases of failure.

This can be useful for pipeing into `await_reply/2`

## Examples

    iex> {:ok, result} = push!(socket, "rooms:lobby", "msg:new", params) |> await_reply()
    {:ok, %{"created?" => true}}

## collect_garbage/1

Requests that the connection process undergoe garbage collection

If you're using Slipstream to send large messages, you may wish to flush
the process memory of the connection process between large messages. This
can be achieved through garbage collection.

## Examples

    iex> collect_garbage(socket)
    :ok

## disconnect/1

Requests that an open connection be closed

This function will no-op when the socket is not currently connected to
any remote websocket server.

Note that you do not need to use `disconnect/1` to clean up a connection.
The connection process monitors the slipstream client process and will shut
down when it detects that the process has terminated.

Disconnection may be awaited synchronously with `await_disconnect/2`

## Examples

    @impl Slipstream
    def handle_info(:chaos_monkey, socket) do
      {:ok, socket} =
        socket
        |> disconnect()
        |> await_disconnect()

      {:noreply, reconnect(socket)}
    end

## await_connect/2

Awaits a pending connection request synchronously

## await_connect!/2

Awaits a pending connection request synchronously, raising on failure

## await_disconnect/2

Awaits a pending disconnection request synchronously

## await_disconnect!/2

Awaits a pending disconnection request synchronously, raising on failure

## await_join/3

Awaits a pending join request synchronously

## await_join!/3

Awaits a join request synchronously, raising on failure

## await_leave/3

Awaits a leave request synchronously

## await_leave!/3

Awaits a leave request synchronously, raising on failure

## await_message/4

Awaits the server's message push

Note that unlike the other `await_*` functions, `await_message/4` is a
macro. This allows an author to match on patterns in the topic, event, and/or
payload parts of a message.

## Examples

    iex> event = "msg:new"
    iex> await_message("rooms:lobby", ^event, %{"user_id" => 5})
    {:ok, "rooms:lobby", "msg:new", %{"user_id" => 5, body: "hello"}}

## await_message!/4

Awaits the server's message push, raising on failure

See `await_message/4`

## await_reply/2

Awaits the server's response to a message

## await_reply!/2

Awaits the server's response to a message, exiting on timeout

See `await_reply/2` for more information.

## __using__/1

Declares that a module is a Slipstream socket client

Slipstream provides a `use Slipstream` macro that behaves similar to
GenServer's `use GenServer`. This does a few things:

- a default implementation of `child_spec/1`, which is used to start the
  module as a GenServer. This may be overridden.
- imports for all documented functions in `Slipstream` and `Slipstream.Socket`
- a `c:GenServer.handle_info/2` function clause which matches incoming events
  from the connection process and dispatches them to the various Slipstream
  callbacks
- a `c:GenServer.handle_info/2` function clause which matches Slipstream
  commands. This is used to implement back-off retry mechanisms for
  `reconnect/1` and `rejoin/3`.

This provides a familiar and sleek interface for the common case of using
Slipstream: an asynchronous callback-based GenServer module.

It's not required to use this macro, though. Slipstream can be used in
synchronous mode (via the `await_*` family of functions).

## Options

Any options passed as the `opts` argument to `__using__/1` are passed along
to `Supervisor.child_spec/2`, as is done in the default `child_spec/1`
implementation for GenServer. Most notably, you may control the restart
strategy of the client with the `:restart` option. See the example below.

## Examples

    defmodule MyApp.MySocketClient do
      # one crash/shutdown/exit will permanently terminate the server
      use Slipstream, restart: :temporary

      def start_link(args) do
        Slipstream.start_link(__MODULE__, args)
      end

      ..
    end