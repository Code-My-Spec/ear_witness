# Membrane.Pipeline

A behaviour module for implementing pipelines.

`Membrane.Pipeline` contains the callbacks and functions for constructing and supervising pipelines.
Pipelines facilitate the convenient instantiation, linking, and management of elements and bins.\
Linking pipeline children together enables them to pass and process data.

To create a pipeline, use `use Membrane.Pipeline` and implement callbacks of `Membrane.Pipeline`  behaviour.
See `Membrane.ChildrenSpec` for details on instantiating and linking children.

## Starting and supervision

Start a pipeline with `start_link/2` or `start/2`. Pipelines always spawn under a dedicated supervisor, so
in the case of success, either function will return `{:ok, supervisor_pid, pipeline_pid}` .

The supervisor never restarts the pipeline, but it does ensure that the pipeline and its children terminate properly.
If the pipeline needs to be restarted, it should be spawned under a different supervisor with the appropriate strategy.

### Starting under a supervision tree

 A pipeline can be spawned under a supervision tree like any other `GenServer`.\
 `use Membrane.Pipeline` injects a `child_spec/1` function. A simple scenario could look like this:

    defmodule MyPipeline do
      use Membrane.Pipeline

      def start_link(options) do
        Membrane.Pipeline.start_link(__MODULE__, options, name: MyPipeline)
      end

      # ...
    end

    Supervisor.start_link([{MyPipeline, option: :value}], strategy: :one_for_one)
    send(MyPipeline, :message)

### Starting outside of a supervision tree

When starting a pipeline outside a supervision tree, use the `pipeline_pid` pid to interact with the pipeline.
 A simple scenario could look like this:

    {:ok, _supervisor_pid, pipeline_pid} = Membrane.Pipeline.start_link(MyPipeline, option: :value)
    send(pipeline_pid, :message)

### Visualizing the supervision tree

Use the [Applications tab](https://www.erlang.org/doc/apps/observer/observer_ug#applications-tab) in Erlang's Observer GUI
(or the `Kino` library in Livebook) to visualize a pipeline's internal supervision tree.

![Observer graph](assets/images/observer_graph.png)

## Terminating

The Pipeline won't terminate automatically - it has to be terminated explicitly 
by executing a `t:Membrane.Pipeline.Action.terminate/0` action. The reason for 
this is the fact that there is no objective way to tell when a Pipeline should terminate.
Even if all of it's children have terminated, it doesn't mean that it should too - more
children can be spawned later on. 

In simpler use cases it's usually enough to terminate the pipeline when a Sink (or all Sinks) 
receive `:end_of_stream`s.

## start_link/3

Starts the pipeline based on the given module and links it to the current process.


Pipeline options are passed to the `c:handle_init/2` callback.
Note that this function returns `{:ok, supervisor_pid, pipeline_pid}` in case of
success. Check the 'Starting and supervision' section of the moduledoc for details.

## start/3

Starts the pipeline outside a supervision tree. Compare to `start_link/3`.

## terminate/2

Terminates the pipeline.

Accepts three options:
* `asynchronous?` - if set to `true`, pipeline termination won't be blocking and
  will be executed in the process whose pid is returned as a function result.
  If set to `false`, pipeline termination will be blocking and will be executed in
  the process that called this function. Defaults to `false`.
* `timeout` - specifies how much time (ms) to wait for the pipeline to gracefully
  terminate. Defaults to 5000.
* `force?` - determines how to handle a pipeline still alive after `timeout`.
  If set to `true`, `Process.exit/2` kills the pipeline with reason `:kill` and returns
  `{:error, :timeout}`.
  If set to `false`, it raises an error. Defaults to `false`.

Returns:
* `{:ok, pid}` - option `asynchronous?: true` was passed.
* `:ok` - pipeline gracefully terminated within `timeout`.
* `{:error, :timeout}` - pipeline was killed after `timeout`.

## call/3

Calls the pipeline with a message.

Returns the result of the pipeline call.

## pipeline?/1

Checks whether the module is a pipeline.

## list_pipelines/0

Returns list of pipeline PIDs currently running on the current node.

Use for debugging only.

## list_pipelines/1

Returns list of pipeline PIDs currently running on the passed node. \
Compare to `list_pipelines/0`.

## __using__/1

Brings all the stuff necessary to implement a pipeline.

Options:
  - `:bring_spec?` - if true (default) imports and aliases `Membrane.ChildrenSpec`
  - `:bring_pad?` - if true (default) requires and aliases `Membrane.Pad`