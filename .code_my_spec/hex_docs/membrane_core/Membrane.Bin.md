# Membrane.Bin

Bins, similarly to pipelines, are containers for elements.
However, at the same time, they can be placed and linked within pipelines.
Although bin is a separate Membrane entity, it can be perceived as a pipeline within an element.
Bins can also be nested within one another.

There are two main reasons why bins are useful:
* they enable creating reusable element groups
* they allow managing their children, for instance by dynamically spawning or replacing them as the stream changes.

In order to create bin `use Membrane.Bin` in your callback module.

## def_input_pad/2

A callback invoked when the bin is being removed by its parent.

By default, it returns `t:Membrane.Bin.Action.terminate/0` with reason `:normal`.

## def_clock/1

Defines that bin exposes a clock which is a proxy to one of its children.

If this macro is not called, no ticks will be forwarded to parent, regardless
of clock definitions in its children.

## bin?/1

Checks whether module is a bin.

## __using__/1

Brings all the stuff necessary to implement a bin.

Options:
  - `:bring_spec?` - if true (default) imports and aliases `Membrane.ChildrenSpec`
  - `:bring_pad?` - if true (default) requires and aliases `Membrane.Pad`