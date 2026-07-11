# Slipstream.Socket

A data structure representing a potential websocket client connection

This structure closely resembles `t:Phoenix.Socket.t/0`, but is not
compatible with its functions. All documented functions from this module
are imported by `use Slipstream`.

## assign/3

Adds key-value pairs to socket assigns

Behaves the same as `Phoenix.Socket.assign/3`

## Examples

    iex> assign(socket, :key, :value)
    iex> assign(socket, key: :value)

## update/3

Updates an existing key in the socket assigns

Raises a `KeyError` if the key is not present in `socket.assigns`.

`func` should be an 1-arity function which takes the existing value at assign
`key` and updates it to a new value. The new value will take the old value's
place in `socket.assigns[key]`.

This function is a useful alternative to `assign/3` when the key is already
present in assigns and is a list, map, or similarly malleable data structure.

## Examples

    @impl Slipstream
    def handle_cast({:join, topic}, socket) do
      socket =
        socket
        |> update(:topics, &[topic | &1])
        |> join(topic)

      {:noreply, socket}
    end

    @impl Slipstream
    def handle_call({:join, topic}, from, socket) do
      socket =
        socket
        |> update(:join_requests, &Map.put(&1, topic, from))
        |> join(topic)

      # note: not replying here so we can provide a synchronous call to a
      # topic being joined
      {:noreply, socket}
    end

    @impl Slipstream
    def handle_join(topic, response, socket) do
      case Map.fetch(socket.assigns.join_requests, topic) do
        {:ok, from} -> GenServer.reply(from, {:ok, response})
        :error -> :ok
      end

      {:ok, socket}
    end

## joined?/2

Checks if a channel is currently joined

## Examples

    iex> joined?(socket, "room:lobby")
    true

## join_status/2

Checks the status of a join request

When a join is requested with `Slipstream.join/3`, the join request is
considered to be in the `:requested` state. Once the topic is successfully
joined, it is considered `:joined` until closed. If there is a failure to
join the topic, if the topic crashes, or if the topic is left after being
joined, the status of the join is considered `:closed`. Finally, if a topic
has not been requested in a join so far for a socket, the status is `nil`.

Notably, the status of a join will not automatically change to `:joined` once
the remote server replies with successful join. Either the join must be
awaited with `Slipstream.await_join/2` or the status may be checked later
in the `c:Slipstream.handle_join/3` callback.

## Examples

    iex> socket = join(socket, "room:lobby")
    iex> join_status(socket, "room:lobby")
    :requested
    iex> {:ok, socket, _join_response} = await_join(socket, "room:lobby")
    iex> join_status(socket, "room:lobby")
    :joined

## connected?/1

Checks if a socket is connected to a remote websocket host

## Examples

    iex> socket = connect(socket, uri: "ws://example.org")
    iex> socket = await_connect!(socket)
    iex> connected?(socket)
    true

## channel_pid/1

Gets the process ID of the connection

The slipstream implementor module is not the same process as the GenServer
which interfaces with the remote server for websocket communication. This
other process, the Slipstream.Connection process, interfaces with the
low-level WebSocket connection and communicates with the implementor module
by puassing messages (mostly with `Kernel.send/2`).

It can be useful to have access to this pid for testing or debugging
purposes, such as sending a fake disconnect message or for getting state
with `:sys.get_state/1`.

## Examples

    iex> Slipstream.Socket.channel_pid(socket)
    #PID<0.1.2>