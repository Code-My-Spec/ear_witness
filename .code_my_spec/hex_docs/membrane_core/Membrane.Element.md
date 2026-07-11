# Membrane.Element

Module containing types and functions for operating on elements.

For behaviours for elements check `Membrane.Source`, `Membrane.Filter`,
`Membrane.Endpoint` and `Membrane.Sink`.

## Behaviours
Element-specific behaviours are specified in modules:
- `Membrane.Element.WithOutputPads` - behaviour common to sources,
filters and endpoints
- `Membrane.Element.WithInputPads` - behaviour common to sinks,
filters and endpoints
- Base modules (`Membrane.Source`, `Membrane.Filter`, `Membrane.Endpoint`,
`Membrane.Sink`) - behaviours specific to each element type.

## Callbacks
Modules listed above provide specifications of callbacks that define elements
lifecycle. All of these callbacks have names with the `handle_` prefix.
They are used to define reaction to certain events that happen during runtime,
and indicate what actions framework should undertake as a result, besides
executing element-specific code.

For actions that can be returned by each callback, see `Membrane.Element.Action`
module.

## element?/1

Checks whether module is an element.