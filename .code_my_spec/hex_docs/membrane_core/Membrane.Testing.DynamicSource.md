# Membrane.Testing.DynamicSource

Testing Element for supplying data based on generator function or payloads passed
through options. It is very similar to `Membrane.Testing.Source` but is has dynamic
pad instead of static.

## Example usage

As mentioned earlier you can use this element in one of two ways, providing
either a generator function or an `Enumerable.t`.

If you provide an `Enumerable.t` with payloads, then each of those payloads will
be wrapped in a `Membrane.Buffer` and sent through `:output` pad.
```
%Source{output: [0xA1, 0xB2, 0xC3, 0xD4]}
```

In order to specify `Membrane.Testing.Source` with generator function you need
to provide initial state and function that matches `t:generator/0` type. This
function should take state and demand size as its arguments and return
a tuple consisting of actions that element will return during the
`c:Membrane.Element.WithOutputPads.handle_demand/5`
callback and new state.

```
generator_function = fn state, pad, size ->
  #generate some buffers
  {actions, state + 1}
end

%Source{output: {1, generator_function}}
```