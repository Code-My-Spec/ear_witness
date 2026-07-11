# Membrane.Core.Stalker



## new/2

Creates a new stalker and configures observability for the pipeline.

Must be called by the pipeline process.

## register_component/2

Registers a component in the stalker and configures the component's observability.

Must be called by an element's or bin's process.

## setup_component_utility/2

Configures observability for a component's utility process.

## generate_observability_data_for_link/2

Generates observability data needed for reporting links and their metrics.

If optionally turned on by setting `report_links_to_observer: true` in
config.exs, starts processes to reflect pads structure in the process tree for visibility
in Erlang observer.

## register_link/4

Registers a link in the stalker. Must be called by the sender element.

## unregister_link/2

Unregisters a link in the stalker. Can be called by both elements of the link.

## subscribe/3

Subscribes for updates from the stalker

The following topics are supported:
- graph - information about the shape of the pipeline, stalker will send `t:graph_update/0` messages
- metrics - metrics from pipeline components, stalker will send `t:metrics_update/0` messages

Subsequent subscription from the same process overrides any previous subscription. If the `confirm: id`
option is passed, the stalker will send a `{:subscribed, id}` message when the subscription is updated.