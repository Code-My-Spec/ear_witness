# Membrane.Tee

Element for forwarding buffers to at least one output pad

It has one input pad `:input` and 2 output pads:
* `:output` - is a dynamic pad which is always available and works in pull mode
* `:push_output` - is a dynamic pad that can be linked to any number of elements (including 0) and works
  in push mode

The `:output` pads dictate the speed of processing data and any element (or elements) connected to
`:push_output` pad will receive the same data as all `:output` instances.