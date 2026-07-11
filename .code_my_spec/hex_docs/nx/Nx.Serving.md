# Nx.Serving

Serving encapsulates client and server work to perform batched requests.

Servings can be executed on the fly, without starting a server, but most
often they are used to run servers that batch requests until a given size
or timeout is reached.

More specifically, servings are a mechanism to apply a computation on a
`Nx.Batch`, with hooks for preprocessing input from and postprocessing
output for the client. Thus we can think of an instance of `t:Nx.Serving.t/0`
(a serving) as something that encapsulates batches of Nx computations.

## Inline/serverless workflow

First, let's define a simple numerical definition function:

    defmodule MyDefn do
      import Nx.Defn

      defn print_and_multiply(x) do
        x = print_value(x, label: "debug")
        x * 2
      end
    end

The function prints the given tensor and doubles its contents.
We can use `new/1` to create a serving that will return a JIT
or AOT compiled function to execute on batches of tensors:

    iex> serving = Nx.Serving.new(fn opts -> Nx.Defn.jit(&MyDefn.print_and_multiply/1, opts) end)
    iex> batch = Nx.Batch.stack([Nx.tensor([1, 2, 3])])
    iex> Nx.Serving.run(serving, batch)
    debug: #Nx.Tensor<
      s64[1][3]
      [
        [1, 2, 3]
      ]
    >
    #Nx.Tensor<
      s64[1][3]
      [
        [2, 4, 6]
      ]
    >

We started the serving by passing a function that receives
compiler options and returns a JIT or AOT compiled function.
We called `Nx.Defn.jit/2` passing the options received as
argument, which will customize the JIT/AOT compilation.

You should see two values printed. The former is the result of
`Nx.Defn.Kernel.print_value/1`, which shows the tensor that was
actually part of the computation and how it was batched.
The latter is the result of the computation.

When defining a `Nx.Serving`, we can also customize how the data is
batched by using the `client_preprocessing` as well as the result by
using `client_postprocessing` hooks. Let's give it another try,
this time using `jit/2` to create the serving, which automatically
wraps the given function in `Nx.Defn.jit/2` for us:

    iex> serving = (
    ...>   Nx.Serving.jit(&MyDefn.print_and_multiply/1)
    ...>   |> Nx.Serving.client_preprocessing(fn input -> {Nx.Batch.stack(input), :client_info} end)
    ...>   |> Nx.Serving.client_postprocessing(&{&1, &2})
    ...> )
    iex> Nx.Serving.run(serving, [Nx.tensor([1, 2]), Nx.tensor([3, 4])])
    debug: #Nx.Tensor<
      s64[2][2]
      [
        [1, 2],
        [3, 4]
      ]
    >
    {{#Nx.Tensor<
        s64[2][2]
        [
          [2, 4],
          [6, 8]
        ]
      >,
      :server_info},
     :client_info}

You can see the results are a bit different now. First of all, notice that
we were able to run the serving passing a list of tensors. Our custom
`client_preprocessing` function stacks those tensors into a batch of two
entries and returns a tuple with a `Nx.Batch` struct and additional client
information which we represent as the atom `:client_info`. The default
client preprocessing simply enforces a batch (or a stream of batches)
was given and returns no client information.

Then the result is a triplet tuple, returned by the client
postprocessing function, containing the result, the server information
(which we will later learn how to customize), and the client information.
From this, we can infer the default implementation of `client_postprocessing`
simply returns the result, discarding the server and client information.

So far, `Nx.Serving` has not given us much. It has simply encapsulated the
execution of a function. Its full power comes when we start running our own
`Nx.Serving` process. That's when we will also learn why we have a `client_`
prefix in some of the function names.

## Stateful/process workflow

`Nx.Serving` allows us to define an Elixir process to handle requests.
This process provides several features, such as batching up to a given
size or time, partitioning, and distribution over a group of nodes.

To do so, we need to start a `Nx.Serving` process with a serving inside
a supervision tree:

    children = [
      {Nx.Serving,
       serving: Nx.Serving.jit(&MyDefn.print_and_multiply/1),
       name: MyServing,
       batch_size: 10,
       batch_timeout: 100}
    ]

    Supervisor.start_child(children, strategy: :one_for_one)

> Note: in your actual application, you want to make sure
> `Nx.Serving` comes early in your supervision tree, for example
> before your web application endpoint or your data processing
> pipelines, as those processes may end-up hitting Nx.Serving.

Now you can send batched runs to said process:

    iex> batch = Nx.Batch.stack([Nx.tensor([1, 2, 3]), Nx.tensor([4, 5, 6])])
    iex> Nx.Serving.batched_run(MyServing, batch)
    debug: #Nx.Tensor<
      s64[2][3]
      [
        [1, 2, 3],
        [4, 5, 6]
      ]
    >
    #Nx.Tensor<
      s64[2][3]
      [
        [2, 4, 6],
        [8, 10, 12]
      ]
    >

In the example, we pushed a batch of 2 and eventually got a reply.
The process will wait for requests from other processes, for up to
100 milliseconds or until it gets 10 entries. Then it merges all
batches together and once the result is computed, it slices and
distributes those responses to each caller.

If there is any `client_preprocessing` function, it will be executed
before the batch is sent to the server. If there is any `client_postprocessing`
function, it will be executed after getting the response from the
server.

### Partitioning

You can start several partitions under the same serving by passing
`partitions: true` when starting the serving. The number of partitions
will be determined according your compiler and for which host it is
compiling.

For example, when creating the serving, you may pass the following
`defn_options`:

    Nx.Serving.new(computation, compiler: EXLA, client: :cuda)

Now when booting up the serving:

    children = [
      {Nx.Serving,
       serving: serving,
       name: MyServing,
       batch_size: 10,
       batch_timeout: 100,
       partitions: true}
    ]

If you have two GPUs, `batched_run/3` will now gather batches and send
them to the GPUs as they become available to process requests.

> #### Cross-device operations {: .warning}
>
> When `partitions: true` is set, you will receive results from
> different GPU devices and Nx won't automatically transfer data
> across devices to avoid surprising performance pitfalls, which
> may lead to errors. In such cases, you probably want to transfer
> tensors back to host on your serving execution.

### Distribution

All `Nx.Serving`s are distributed by default. If the current machine
does not have an instance of `Nx.Serving` running, `batched_run/3` will
automatically look for one in the cluster. The nodes do not need to run
the same code and applications. It is only required that they run the
same `Nx` version.

The load balancing between servings is done randomly by default, however,
the number of partitions are considered if the `partitions: true` option is also given.
For example, if you have a node with 2 GPUs and another with 4, the latter
will receive the double of requests compared to the former.

Furthermore, the load balancing allows for assigning weights to servings.
Similarly to the number of partitions, when running a serving with `distribution_weight: 1`
and another one with `distribution_weight: 2`, the latter will receive double the requests
compared to the former.

`batched_run/3` receives an optional `distributed_preprocessing` callback as
third argument for preprocessing the input for distributed requests. When
using libraries like EXLA or Torchx, the tensor is often allocated in memory
inside a third-party library so it is necessary to either transfer or copy
the tensor to the binary backend before sending it to another node.
This can be done by passing either `Nx.backend_transfer/1` or `Nx.backend_copy/1`
as third argument:

    Nx.Serving.batched_run(MyDistributedServing, input, &Nx.backend_copy(&1, Nx.BinaryBackend))

Use `backend_transfer/1` if you know the input will no longer be used.

Similarly, the serving has a `distributed_postprocessing` callback which is
called on the remote machine before sending the reply to the caller. It can
be used to transfer resources to the binary backend before sending them over
the network.

The servings are dispatched using Erlang Distribution. You can use
`Node.connect/1` to manually connect nodes. In a production setup, this is
often done with the help of libraries like [`libcluster`](https://github.com/bitwalker/libcluster).

## Advanced notes

### Module-based serving

In the examples so far, we have been using the default version of
`Nx.Serving`, which executes the given function for each batch.

However, we can also use `new/2` to start a module-based version of
`Nx.Serving` which gives us more control over both inline and process
workflows. A simple module implementation of a `Nx.Serving` could look
like this:

    defmodule MyServing do
      @behaviour Nx.Serving

      defnp print_and_multiply(x) do
        x = print_value({:debug, x})
        x * 2
      end

      @impl true
      def init(_inline_or_process, :unused_arg, [defn_options]) do
        {:ok, Nx.Defn.jit(&print_and_multiply/1, defn_options)}
      end

      @impl true
      def handle_batch(batch, 0, function) do
        {:execute, fn -> {function.(batch), :server_info} end, function}
      end
    end

It has two functions. The first, `c:init/3`, receives the type of serving
(`:inline` or `:process`) and the serving argument. In this step,
we capture `print_and_multiply/1`as a jitted function.

The second function is called `c:handle_batch/3`. This function
receives a `Nx.Batch` and returns a function to execute.
The function itself must return a two element-tuple: the batched
results and some server information. The server information can
be any value and we set it to the atom `:server_info`.

Now let's give it a try by defining a serving with our module and
then running it on a batch:

    iex> serving = Nx.Serving.new(MyServing, :unused_arg)
    iex> batch = Nx.Batch.stack([Nx.tensor([1, 2, 3])])
    iex> Nx.Serving.run(serving, batch)
    {:debug, #Nx.Tensor<
      s64[1][3]
      [
        [1, 2, 3]
      ]
    >}
    #Nx.Tensor<
      s64[1][3]
      [
        [2, 4, 6]
      ]
    >

From here on, you use `start_link/1` to start this serving in your
supervision and even customize `client_preprocessing/1` and
`client_postprocessing/1` callbacks to this serving, as seen in the
previous sections.

Note in our implementation above assumes it won't run partitioned.
In partitioned mode, `c:init/3` may receive multiple `defn_options`
as the third argument and `c:handle_batch/3` may receive another partition
besides 0.

### Streaming

`Nx.Serving` allows both inputs and outputs to be streamed.

In order to stream inputs, you only need to return a stream of `Nx.Batch`
from the `client_preprocessing` callback. Serving will automatically take
care of streaming the inputs in, regardless if using `run/2` or `batched_run/2`.
It is recommended that the streaming batches have the same size as `batch_size`,
to avoid triggering `batch_timeout` on every iteration (except for the last one
which may be incomplete).

To stream outputs, you must invoke `streaming/2` with any additional
streaming configuration. When this is invoked, the `client_postprocessing`
will receive a stream which you can further manipulate lazily using the
functions in the `Stream` module. `streaming/2` also allows you to configure
hooks and stream values directly from `Nx.Defn` hooks. However, when hook
streaming is enabled, certain capabilities are removed: you cannot stream
inputs nor have batches larger than the configured `batch_size`.

You can enable both input and output streaming at once.

### Batch keys

Sometimes it may be necessary to execute different functions under the
same serving. For example, sequence transformers must pad the sequence
to a given length. However, if you are batching, the length must be
padded upfront. If the length is too small, you have to either discard
data or support only small inputs. If the length is too large, then you
decrease performance with the extra padding.

Batch keys provide a mechanism to accumulate different batches, based on
their key, which execute independently. As an example, we will do a
serving which performs different operations based on the batch key,
but it could also be used to perform the same operation for different
templates:

    iex> args = [Nx.template({10}, :s32)]
    iex> serving = Nx.Serving.new(fn
    ...>   :double, opts -> Nx.Defn.compile(&Nx.multiply(&1, 2), args, opts)
    ...>   :half, opts -> Nx.Defn.compile(&Nx.divide(&1, 2), args, opts)
    ...> end)
    iex> double_batch = Nx.Batch.concatenate([Nx.iota({10})]) |> Nx.Batch.key(:double)
    iex> Nx.Serving.run(serving, double_batch)
    #Nx.Tensor<
      s32[10]
      [0, 2, 4, 6, 8, 10, 12, 14, 16, 18]
    >
    iex> half_batch = Nx.Batch.concatenate([Nx.iota({10})]) |> Nx.Batch.key(:half)
    iex> Nx.Serving.run(serving, half_batch)
    #Nx.Tensor<
      f32[10]
      [0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5]
    >

When using a process-based serving, you must specify the supported
`:batch_keys` when the process is started. The batch keys will be
available inside the `defn_options` passed as the third argument of
the `c:init/3` callback. The batch keys will also be verified
when the batch is returned from the client-preprocessing callback.

## new/2

Creates a new function serving.

It expects a single- or double-arity function. If a single-arity
function is given, it receives the compiler options and must
return a JIT (via `Nx.Defn.jit/2`) or AOT compiled (via
`Nx.Defn.compile/3`) one-arity function.

If a double-arity function is given, it receives the batch
key as first argument and the compiler options as second argument.
It must return a JIT (via `Nx.Defn.jit/2`) or AOT compiled
(via `Nx.Defn.compile/3`) one-arity function, but in practice
it will be a `Nx.Defn.compile/3`, since the purpose of the
batch key is often to precompile different versions of the
same function upfront. The batch keys can be given on
`start_link/1`.

The function will be called with the arguments returned by the
`client_preprocessing` callback.

## batch_size/2

Sets the batch size for this serving.

This batch size is used to split batches given to both `run/2` and
`batched_run/2`, enforcing that the batch size never goes over a limit.
If you only want to batch within the serving process, you must set
`:batch_size` via `process_options/2` (or on `start_link/1`).

Note that `:batch_size` only guarantees a batch does not go over a limit.
Batches are not automatically padded to the batch size. Such can be done
as necessary inside your serving function by calling `Nx.Batch.pad/2`.

> #### Why batch on `run/2`? {: .info}
>
> By default, `run/2` does not place a limit on its input size. It always
> processes inputs directly within the current process. On the other hand,
> `batched_run/2` always sends your input to a separate process, which
> will batch and execute the serving only once the batch is full or a
> timeout has elapsed.
>
> However, in some situations, an input given to `run/2` needs to be
> broken into several batches. If we were to very large batches to our
> computation, the computation could require too much memory. In such
> cases, setting a batch size even on `run/2` is beneficial, because
> Nx.Serving takes care of splitting a large batch into smaller ones
> that do not exceed the `batch_size` value.

## jit/2

Creates a new serving by jitting the given `fun` with `defn_options`.

This is equivalent to:

    new(fn opts -> Nx.Defn.jit(fun, opts) end, defn_options)

## new/3

Creates a new module-based serving.

It expects a module and an argument that is given to its `init`
callback.

A third optional argument called `defn_options` are additional
compiler options which will be given to the module. Those options
will be merged into `Nx.Defn.default_options/0`.

## client_preprocessing/2

Sets the client preprocessing function.

The default implementation expects a `Nx.Batch` or a stream of
Nx.Batch to be given as input and return them as is.

## client_postprocessing/2

Sets the client postprocessing function.

The client postprocessing receives a tuple with the
`{output, metadata}` or a stream as first argument.
The second argument is always the additional information
returned by the client preprocessing.

The default implementation returns either the output or
the stream.

## distributed_postprocessing/2

Sets the distributed postprocessing function.

The default implementation is `Function.identity/1`.

## streaming/2

Configure the serving to stream its results.

Once `run/2` or `batched_run/2` are invoked, it will then
return a stream. The stream must be consumed in the same
process that calls `run/2` or `batched_run/2`.

Batches will be streamed as they arrive. You may also opt-in
to stream `Nx.Defn` hooks.

## Options

  * `:hooks` - a list of hook names that will become streaming events

## Implementation details

### Client postprocessing

Once streaming is enabled, the client postprocessing callback
will receive a stream which will emit events for each hook
in the shape of:

    {hook_name, term()}

The stream will also receive events in the shape of
`{:batch, output, metadata}` as batches are processed by the
serving. The client postprocessing is often expected to call
`Stream.transform/3` to process those events into something
usable by callers.

If the `:hooks` option is given, only a single `:batch` event
is emitted, at the end, as detailed next.

### Batch limits

If you are streaming hooks, the serving server can no longer break
batch and you are unable to push a payload bigger than `:batch_size`.
For example, imagine you have a `batch_size` of 3 and you push three
batches of two elements (AA, BB, and CC). Without hooks, the batches
will be consumed as:

    AAB -> BCC

With streaming, we can't break the batch `BB`, as above, so we will
consistently pad with zeroes:

    AA0 -> BB0 -> CC0

In practice, this should not be a major problem, as you should
generally avoid having a batch size that is not a multiple of the
most common batches.

## process_options/2

Sets the process options of this serving.

These are the same options as supported on `start_link/1`,
except `:name` and `:serving` itself.

## defn_options/2

Sets the defn options of this serving.

These are the options supported by `Nx.Defn.default_options/1`.

## run/2

Runs `serving` with the given `input` inline with the current process.

The `serving` is executed immediately, without waiting or batching inputs
from other processes. If a `batch_size/2` is specified, then the input may
be split or padded, but they are still executed immediately inline.

## start_link/1

Starts a `Nx.Serving` process to batch requests to a given serving.

## Options

All options, except `:name` and `:serving`, can also be set via
`process_options/2`.

  * `:name` - an atom with the name of the process

  * `:serving` - a `Nx.Serving` struct with the serving configuration

  * `:batch_keys` - all available batch keys. Batch keys allows Nx.Serving
    to accumulate different batches with different properties. Defaults to
    `[:default]`

  * `:batch_size` - the maximum batch size. A default value can be set with
    `batch_size/2`, which applies to both `run/2` and `batched_run/2`.
    Setting this option only affects `batched_run/2` and it defaults to `1`
    if none is set. Note batches received by the serving are not automatically
    padded to the batch size, such can be done with `Nx.Batch.pad/2`.

  * `:batch_timeout` - the maximum time to wait, in milliseconds,
    before executing the batch (defaults to `100`ms)

  * `:partitions` - when `true`, starts several partitions under this serving.
    The number of partitions will be determined according to your compiler
    and for which host it is compiling. See the module docs for more information

  * `:distribution_weight` - weight used for load balancing when running
    a distributed serving. Defaults to `1`.
    If it is set to a higher number `w`, the serving process will receive,
    on average, `w` times the number of requests compared to the
    default. Note that the weight is multiplied with the number of
    partitions, if partitioning is enabled.

  * `:shutdown` - the maximum time for the serving to shutdown. This will
    block until the existing computation finishes (defaults to `30_000`ms)

  * `:hibernate_after` and `:spawn_opt` - configure the underlying serving
    workers (see `GenServer.start_link/3`)

## batched_run/3

Runs the given `input` on the serving process given by `name`.

`name` is either an atom representing a local or distributed
serving process. First it will attempt to dispatch locally, then it
falls back to the distributed serving. You may specify
`{:local, name}` to force a local lookup or `{:distributed, name}`
to force a distributed one.

The `client_preprocessing` callback will be invoked on the `input`
which is then sent to the server. The server will batch requests
and send a response either when the batch is full or on timeout.
Then `client_postprocessing` is invoked on the response. See the
module documentation for more information. In the distributed case,
the callbacks are invoked in the distributed node, but still outside of
the serving process.

Note that you cannot batch an `input` larger than the configured
`:batch_size` in the server.

## Distributed mode

To run in distributed mode, the nodes do not need to run the same
code and applications. It is only required that they run the
same `Nx` version.

If the current node is running a serving given by `name` locally
and `{:distributed, name}` is used, the request will use the same
distribution mechanisms instead of being handled locally, which
is useful for testing locally without a need to spawn nodes.

This function receives an optional `distributed_preprocessing` callback as
third argument for preprocessing the input for distributed requests. When
using libraries like EXLA or Torchx, the tensor is often allocated in memory
inside a third-party library so it may be necessary to either transfer or copy
the tensor to the binary backend before sending it to another node.
This can be done by passing either `Nx.backend_transfer/1` or `Nx.backend_copy/1`
as third argument:

    Nx.Serving.batched_run(MyDistributedServing, input, &Nx.backend_copy/1)

Use `backend_transfer/1` if you know the input will no longer be used.

Similarly, the serving has a `distributed_postprocessing` callback which can do
equivalent before sending the reply to the caller.