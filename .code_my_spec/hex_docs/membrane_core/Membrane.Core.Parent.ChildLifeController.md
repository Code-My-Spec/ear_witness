# Membrane.Core.Parent.ChildLifeController



## handle_spec/2

Handles `Membrane.ChildrenSpec` returned with `spec` action.

Handling a spec consists of the following steps:
- Parse the spec
- Set up `Membrane.Sync`s
- Spawn children processes. If any process crashes when being spawned (that is in `handle_init`),
  the parent is terminated.
- Activate syncs and choose clock
- Set spec status to `:initializing` and store the spec in `pending_specs` in state. It's kept there
  until the spec is fully handled. If any child of the spec that is in a crash group crashes by then,
  the spawning of the spec is cancelled and spec is cleaned up. That's possible because only one crash
  group per spec is allowed.
- Optionally add crash group
- Execute `handle_spec_startup` callback
- Wait until all children are initialized and all dependent specs are fully handled. Dependent specs are
  those containing children that are linked in the current spec.
- Set spec status to `:initialized`
- Send link requests for all the links in the spec. Set spec status to `:linking_internally`. Wait until
  all link responses are received.
- Link all links that are not involving bin pads.
- If the parent is bin, send link responses for bin pads, set spec status to `:linking_externally` and wait
  until all bin pads of the spec are linked. Linking bin pads is actually routing link calls to proper
  bin children.
- Mark spec children as ready, optionally request to play or terminate
- Cleanup spec: remove it from `pending_specs` and all other specs' `dependent_specs` and try proceeding startup
  for all other pending specs that depended on the spec.

## handle_child_death/3

Handles death of a child:
- removes it from state
- unlinks it from other children
- handles crash group (if applicable)