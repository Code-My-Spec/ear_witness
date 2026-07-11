# Membrane.Element.WithInputPads

Module defining behaviour for sink, filter and endpoint elements.

When used declares behaviour implementation, provides default callback definitions
and imports macros.

For more information on implementing elements, see `Membrane.Element.Base`.

## def_input_pad/2

Callback that is called when buffer should be processed by the Element.

For pads in pull mode it is called when buffer have been demanded (by returning
`:demand` action from any callback).

For pads in push mode it is invoked when buffer arrive.