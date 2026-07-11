# Kino.Process

This module contains kinos for generating visualizations to help
introspect your running processes.

## app_tree/2

Generates a visualization of an application tree.

Given the name of an application as an atom, this function will render the
application tree. It is displayed with solid lines denoting supervisor-worker
relationships and dotted lines denoting links between processes. The graph
rendering supports the following options:

## Options

  * `:direction` - defines the direction of the graph visual. The
    value can either be `:top_down` or `:left_right`. Defaults to `:top_down`.

  * `:render_ets_tables` - determines whether ETS tables associated with the
    supervision tree are rendered. Defaults to `false`.

  * `:caption` - an optional caption for the diagram. Either a custom
    caption as string, or `nil` to disable the default caption.

## Examples

To view the applications running in your instance run:

    :application_controller.which_applications()

You can then call `Kino.Process.app_tree/1` to render
the application tree using using the atom of the application.

    Kino.Process.app_tree(:logger)

You can also change the direction of the rendering by calling
`Kino.Process.app_tree/2` with the `:direction` option.

    Kino.Process.app_tree(:logger, direction: :left_right)

## sup_tree/2

Generates a visualization of a supervision tree.

The provided supervisor can be either a named process or a PID. The supervision tree
is displayed with solid lines denoting supervisor-worker relationships and dotted
lines denoting links between processes. The graph rendering supports the following
options:

## Options

  * `:direction` - defines the direction of the graph visual. The
    value can either be `:top_down` or `:left_right`. Defaults to `:top_down`.

  * `:caption` - an optional caption for the diagram. Either a custom
    caption as string, or `nil` to disable the default caption.

## Examples

With a supervisor definition like so:

    {:ok, supervisor_pid} =
      Supervisor.start_link(
        [
          {DynamicSupervisor, strategy: :one_for_one, name: MyApp.DynamicSupervisor},
          {Agent, fn -> [] end}
        ],
        strategy: :one_for_one,
        name: MyApp.Supervisor
      )

    Enum.each(1..3, fn _ ->
      DynamicSupervisor.start_child(MyApp.DynamicSupervisor, {Agent, fn -> %{} end})
    end)

You can then call `Kino.Process.sup_tree/1` to render
the supervision tree using using the PID of the supervisor.

    Kino.Process.sup_tree(supervisor_pid)

You can also render the supervisor by passing the name of the supervisor
if the supervisor was started with a name.

    Kino.Process.sup_tree(MyApp.Supervisor)

You can also change the direction of the rendering by calling
`Kino.Process.sup_tree/2` with the `:direction` option.

    Kino.Process.sup_tree(MyApp.Supervisor, direction: :left_right)

## render_app_tree/2

Renders a visual of the provided application tree.

This function renders an application tree much like `app_tree/2` with the difference
being that this function can be called anywhere within the Livebook code block
whereas `app_tree/2` must have its result be the last thing returned from the code
block in order to render the visual. It supports the same options as `app_tree/2` as
it delegates to that function to generate the visual.

## render_seq_trace/3

Renders a sequence diagram of process messages and returns the function result.

This function renders a sequence diagram much like `seq_trace/2` with the difference
being that this function can be called anywhere within the Livebook code block
whereas `seq_trace/2` must have its result be the last thing returned from the code
block in order to render the visual. In addition, this function returns the result
from the provided trace function.

## render_sup_tree/2

Renders a visual of the provided supervision tree.

This function renders a supervision tree much like `sup_tree/2` with the difference
being that this function can be called anywhere within the Livebook code block
whereas `sup_tree/2` must have its result be the last thing returned from the code
block in order to render the visual. It supports the same options as `sup_tree/2` as
it delegates to that function to generate the visual.

## seq_trace/3

Generate a sequence diagram of process messages starting from `self()`.

The provided function is executed and traced, with all the events sent to and
received by the trace target processes rendered in a sequence diagram. The trace
target argument can either be a single PID, a list of PIDs, or the atom `:all`
depending on what messages you would like to retain in your trace.

## Options

  * `:message_label` - A function to label message events. If
    the given function returns `:continue`, then the default label
    is used. However, if the function returns `{:ok, String.t()}`,
    then the given string will be used for the label.

  * `:caption` - an optional caption for the diagram. Either a custom
    caption as string, or `nil` to disable the default caption.

## Examples

To generate a trace of all the messages occurring during the execution of the
provided function, you can do the following:

    Kino.Process.seq_trace(fn ->
      {:ok, agent_pid} = Agent.start_link(fn -> [] end)
      Process.monitor(agent_pid)

      1..2
      |> Task.async_stream(
        fn value ->
          Agent.get(agent_pid, fn value -> value end)
          100 * value
        end,
        max_concurrency: 3
      )
      |> Stream.run()

      Agent.stop(agent_pid)
    end)

If you are only interested in messages being sent to or received by certain PIDs,
you can filter the sequence diagram by specifying the PIDs that you are interested
in:

    {:ok, agent_pid} = Agent.start_link(fn -> [] end)
    Process.monitor(agent_pid)

    Kino.Process.seq_trace(agent_pid, fn ->
      1..2
      |> Task.async_stream(
        fn value ->
          Agent.get(agent_pid, fn value -> value end)
          100 * value
        end,
        max_concurrency: 3
      )
      |> Stream.run()

      Agent.stop(agent_pid)
    end)

Further if you are interested in custom labeling between messages
sent between processes, you can specify custom labels for the
messages you are interested in:

    {:ok, agent_pid} = Agent.start_link(fn -> [] end)
    Process.monitor(agent_pid)

    Kino.Process.seq_trace(agent_pid, fn ->
      1..2
      |> Task.async_stream(
        fn value ->
          Agent.get(agent_pid, fn value -> value end)
          100 * value
        end,
        max_concurrency: 3
      )
      |> Stream.run()

      Agent.stop(agent_pid)
    end,
    message_label: fn(msg) ->
      case msg do
        {:"$gen_call", _ref, {:get, _}} -> {:ok, "GET: value"}
        _ -> :continue
      end
  end)