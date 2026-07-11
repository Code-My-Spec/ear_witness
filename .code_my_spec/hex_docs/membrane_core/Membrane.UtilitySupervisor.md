# Membrane.UtilitySupervisor

A supervisor responsible for managing utility processes under the pipeline's
supervision tree.

The supervisor is spawned with each component and can be accessed from callback contexts.

`Membrane.UtilitySupervisor` does not restart processes. Rather, it ensures that these utility processes
terminate gracefully when the component that initiated them terminates.

If a process needs to be able to restart, spawn a dedicated supervisor  under this supervisor.

## Example

    def handle_setup(ctx, state) do
      Membrane.UtilitySupervisor.start_link_child(
        ctx.utility_supervisor,
        {MySupervisor, children: [SomeWorker, OtherWorker], restart: :one_for_one})
    end