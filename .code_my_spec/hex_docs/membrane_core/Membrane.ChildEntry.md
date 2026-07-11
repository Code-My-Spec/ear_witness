# Membrane.ChildEntry

Struct describing child entry of a parent.

The public fields are:
- `name` - child name
- `module` - child module
- `group` - child group name
- `options` - options passed to the child
- `component_type` - either `:element` or `:bin`
- `playback` - either `:stopped` or `:playing`

Other fields in the struct ARE NOT PART OF THE PUBLIC API and should not be
accessed or relied on.