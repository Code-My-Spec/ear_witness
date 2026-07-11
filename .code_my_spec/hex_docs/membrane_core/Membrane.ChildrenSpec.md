# Membrane.ChildrenSpec

A module with functionalities that allow to represent a topology of a pipeline/bin.

The children specification (commonly referred to as a "children_spec") is represented by the following type:
`t:t/0`. It consists of two parts - a children's specification and the children's specification options.

The children's specification describes the desired topology and can be incorporated into a pipeline or a bin by returning
`t:Membrane.Pipeline.Action.spec/0` or `t:Membrane.Bin.Action.spec/0`
action, respectively. This commonly happens within `c:Membrane.Pipeline.handle_init/2`
and `c:Membrane.Bin.handle_init/2`, but can be done in any other callback also.

## Children's specification
The children's specification allows specifying the children that need to be spawned in the action, as well as
links between the children (both the children spawned in that action, and already existing children).

The children's processes are spawned with the use of `child/1`, `child/2`, `child/3` and `child/4` functions.
These functions can be used for spawning nodes of a link in an inline manner:
```
  spec = [child(:source, Source) |> child(:filter, %Filter{option: 1}) |> child(:sink, Sink)]
```
or just to spawn children processes, without linking the newly created children:
```
  spec = [child(:source, Source),
    child(:filter, Filter),
    child(:sink, Sink)
  ]
```

Providing a child name is not necessary - you can spawn an anonymous child if you do not
need to refer to that child later on:
```
  spec = child(Source) |> child(Filter)
```
Children created that way will have their automatically generated identifier consisting of a module
name and a random unique reference number, so that you will be able to distinguish between anonymous
children i.e. in log prints.

In case you need to refer to an already existing child (which could be spawned, i.e. in the previous `spec` action),
use `get_child/1` and `get_child/2` functions, as in the example below:
```
  spec = [get_child(:already_existing_source) |> child(:this_filter_will_be_spawned, Filter) |> get_child(:already_existing_sink)]
```

The `child` functions allow specifying `:get_if_exists` option.
It might be helpful when you are not certain if the child with the given name exists, and, therefore, you are unable to
choose between `get_child` and `child` functions. After setting the `get_if_exists: true` option in `child/3` and `child/4` functions you can be sure
that in case a child with a given name already exists, you will simply refer to that child instead of respawning it.
```
  spec = [child(:sink, Sink),
    child(:sink, Sink, get_if_exists: true) |> child(:source, Source)]
```
In the example above you can see, that the `:sink` child is created in the first element of the `spec` list.
In the second element of that list, the `get_if_exists: true` option is used within `child/3`, which will have the same effect as if
`get_child(:sink)` was used. At the same time, if the `:sink` child wasn't already spawned, it would be created in that link definition.
Please note that it makes sense to use `:get_if_exists` option only with named children.

### Links between pads

`via_in/2` and `via_out/2` functions allow
specifying pads' names and parameters. If pads are not specified, name `:input`
is assumed for inputs and `:output` for outputs.

Sample definition:

```
[
  get_child(:source_a)
  |> get_child(:converter)
  |> via_in(:input_a, target_queue_size: 20)
  |> get_child(:mixer),
  get_child(:source_b)
  |> via_out(:custom_output)
  |> via_in(:input_b, options: [mute: true])
  |> get_child(:mixer)
  |> via_in(:input, toilet_capacity: 500)
  |> get_child(:sink)
]
```

See the docs for `via_in/3` and `via_out/3` for details on pad properties that can be set.
Links can also contain children's definitions, for example:

```
[
  child(:first_element, %Element.With.Options.Struct{option_a: 42})
  |> child(:some_element, Element.Without.Options)
  |> get_child(:element_specified_before)
]
```

### Bins

For bin boundaries, there are special links allowed. The user should define links
between the bin's input and the first child's input (input-input type) and the last
child's output and bin output (output-output type). In this case, `bin_input/1`
and `bin_output/2` should be used.

Sample definition:

```
[
  bin_input() |> get_child(:filter1) |> get_child(:filter2) |> bin_output(:custom_output)
]
```

### Dynamic pads

In most cases, dynamic pads can be linked the same way as static ones, although
in the following situations, an exact pad reference must be passed instead of a name:

- When that reference is needed later, for example, to handle a notification related
to that particular pad instance

```
pad = Pad.ref(:output, make_ref())
[
  get_child(:tee) |> via_out(pad) |> get_child(:sink)
]
```

- When linking dynamic pads of a bin with its children, for example in
`c:Membrane.Bin.handle_pad_added/3`

```
@impl true
def handle_pad_added(Pad.ref(:input, _) = pad, _ctx, state) do
  spec = [bin_input(pad) |> get_child(:mixer)]
  {{:ok, spec: spec}, state}
end
```

## Children's specification options

### Stream sync

`:stream_sync` field can be used for specifying elements that should start playing
at the same moment. An example can be audio and video player sinks. This option
accepts either `:sinks` atom or a list of groups (lists) of elements. Passing `:sinks`
results in synchronizing all sinks in the pipeline, while passing a list of groups
of elements synchronizes all elements in each group. It is worth mentioning
that to keep the stream synchronized all involved elements need to rely on
the same clock.

By default, no elements are synchronized.

Sample definitions:

```
children = ...
  {children, stream_sync: [[:element1, :element2], [:element3, :element4]]}
  {children, stream_sync: :sinks}
```

### Clock provider

A clock provider is an element that exports a clock that should be used as the pipeline
clock. The pipeline clock is the default clock used by elements' timers.
For more information see `Membrane.Element.Base.def_clock/1`.

### Children groups
Children groups allow aggregating the spawned children into easily identifiable groups.
With the use of them, it is possible to refer to all the children of the group with a single identifier.
Example:
```
  spec1 = {links1, group: :first_children_group}
  spec2 = {links2, group: :second_children_group}
```
The children spawned within `links1` specification will be put inside `:first_children_group`, whereas the
children spawned within `links2` specification will be put inside `second_children_group`.

Later on, the children from a given group can be referred with their `group`, as in the example below:
```
  actions = [remove_children: :first_children_group]
```
With the action defined above, all the children from the `:first_children_group` can be removed at once.

### Crash groups

A crash group is a logical entity that prevents the whole pipeline from crashing when one of
components crashes. A crash group is defined with the use of two children specification options:
* `group` - which acts as a crash group identifier
* `crash_group_mode` - its value specifies the behavior of children in the crash group. Currently, we support only
`:temporary` mode which means that Membrane will not make any attempts to restart crashed child.

#### Adding children to a crash group

```
spec = [
  child(:some_element_1, %SomeElement{
    # ...
  },
  child(:some_element_2, %SomeElement{
    # ...
  }
]

spec = {spec, group: group_id, crash_group_mode: :temporary}
```

In the above snippet, we create new children - `:some_element_1` and `:some_element_2`, we add them
to the crash group with id `group_id`. Crash of `:some_element_1` or `:some_element_2` propagates
only to the rest of the members of the crash group and the pipeline stays alive.

#### Handling crash of a crash group

When any of the members of the crash group goes down, the callback:
[`handle_crash_group_down/3`](https://hexdocs.pm/membrane_core/Membrane.Pipeline.html#c:handle_crash_group_down/3)
is called.

```
@impl true
def handle_crash_group_down(crash_group_id, ctx, state) do
  # do some stuff in reaction to the crash of the group with id crash_group_id
end
```

#### Limitations

At this moment crash groups are only useful for elements with dynamic pads.
Crash groups work in pipelines and bins as well.

### Log metadata
`:log_metadata` field can be used to set the `Membrane.Logger` metadata for all children in the given children specification.

## Nesting children's specifications
The children's specifications can be nested within themselves.

Consider the following children's specifications:
```
{[
  child(:a, A) |> child(:b, B),
  {child(:c, C), group: :second, crash_group_mode: :temporary}
], group: :first, crash_group_mode: :temporary, node: some_node}
```

Child `:c` will be spawned in the `:second` crash group, while children `:a` and `:b` will be spawned in the `:first` crash group.
Furthermore, since the inner children specification does not define the `:node` option, it will be inherited from the outer children specification.
That means that child `:c` will be spawned on the `some_node` node, along with children `:a` and `:b`.

## get_child/1

Used to refer to an existing child at a beginning of a link specification.

See the _Children's specification_ section of the moduledoc for more information.

## get_child/2

Used to refer to an existing child in a middle of a link specification.

See the _Children's specification_ section of the moduledoc for more information.

## child/1

Used to spawn an anonymous child at the beggining of the link specification.

See the _Children's specification_ section of the moduledoc for more information.

## child/2

Used to spawn a named child at the beggining of the link
specification or to spawn an anynomous child.

See the _Children's specification_ section of the moduledoc for more information.

## child/3

Used to spawn a named child or an anonymous child in the middle
of the link specification.

See the _Children's specification_ section of the moduledoc for more information.

## child/4

Used to spawn a named child in the middle of a link specification.

See the _Children's specification_ section of the moduledoc for more information.

## bin_input/1

Begins a link with a bin's pad.

See the _Children's specification_ section of the moduledoc for more information.

## bin_output/2

Ends a link with a bin's output.

See the _Children's specification_ section of the moduledoc for more information.

## via_out/3

Specifies output pad name and properties of the preceding child.

The possible properties are:
- `options` - If a pad defines options, they can be passed here as a keyword list. Pad options are documented
in moduledoc of each element. See `Membrane.Element.WithOutputPads.def_output_pad/2` and `Membrane.Bin.def_output_pad/2`
for information about defining pad options.

See the _Children's specification_ section of the moduledoc for more information.