# Membrane.Testing.Pipeline

This Pipeline was created to reduce testing boilerplate and ease communication
with its children. It also provides a utility for informing testing process about
playback changes and received notifications.

When you want a build Pipeline to test your children you need three things:
 - Pipeline Module
 - List of children
 - Links between those children

To start a testing pipeline you need to build
a keyword list representing the options used to determine the pipeline's behaviour and then
pass that options list to the `Membrane.Testing.Pipeline.start_link_supervised!/1`.
The testing pipeline can be started in one of two modes - either with its `:default` behaviour, or by
injecting a custom module behaviour. The usage of a `:default` pipeline implementation is presented below:
```
spec = [
    child(:el1, MembraneElement1)
    |> child(:el2, MembraneElement2)
    ...
]

options =  [
  module: :default # :default is the default value for this parameter, so you do not need to pass it here
  spec: spec
]

pipeline = Membrane.Testing.Pipeline.start_link_supervised!(options)
```
You can also pass your custom pipeline's module as a `:module` option of
the options list. Every callback of the module
will be executed before the callbacks of Testing.Pipeline.
Passed module has to return a proper spec. There should be no children
nor links specified in options passed to test pipeline as that would
result in a failure.
```
options = [
  module: Your.Module
]

pipeline = Membrane.Testing.Pipeline.start_link_supervised!(options)
```
See `t:Membrane.Testing.Pipeline.options/0` for available options.

## Assertions

This pipeline is designed to work with `Membrane.Testing.Assertions`. Check
them out or see example below for more details.

## Messaging children

You can send messages to children using their names specified in the children
list. Please check `notify_child/3` for more details.

## Example usage

Firstly, we can start the pipeline providing its options as a keyword list:
```
import Membrane.ChildrenSpec

spec = [
    child(:source, %Membrane.Testing.Source{output: [1, 2, 3]})
    |> child(:tested_element, TestedElement)
    |> child(:sink, Membrane.Testing.Sink)
]

{:ok, pipeline} = Membrane.Testing.Pipeline.start_link(spec: spec)
```
We can now wait till the end of the stream reaches the sink element (don't forget
to import `Membrane.Testing.Assertions`):

    assert_end_of_stream(pipeline, :sink)

We can also assert that the `Membrane.Testing.Sink` processed a specific
buffer:

    assert_sink_buffer(pipeline, :sink, %Membrane.Buffer{payload: 1})

## start_link_supervised/1

Starts the pipeline under the ExUnit test supervisor and links it to the current process.

Can be used only in tests.

## start_supervised/1

Starts the pipeline under the ExUnit test supervisor.

Can be used only in tests.

## notify_child/3

Sends notification to a child by Element name.

## Example

Knowing that `pipeline` has child named `sink`, notification can be sent as follows:

    notify_child(pipeline, :sink, {:notification, "to handle"})

## message_child/3

Deprecated since `v1.1.0`, use `notify_child/3` instead.

Sends message to a child by Element name.

## Example

Knowing that `pipeline` has child named `sink`, message can be sent as follows:

    message_child(pipeline, :sink, {:message, "to handle"})

## execute_actions/2

Executes specified actions in the pipeline.

The actions are returned from the `handle_info` callback.

## get_child_pid/2

Returns the pid of the children process.

Accepts pipeline pid as a first argument and a child reference or a list
of child references representing a path as a second argument.

If second argument is a child reference, function gets pid of this child
from pipeline.

If second argument is a path of child references, function gets pid of
last a component pointed by this path.

Returns
 * `{:ok, child_pid}`, if a child was succesfully found
 * `{:error, reason}`, if, for example, pipeline is not alive or children path is invalid

## get_child_pid!/2

Returns the pid of the children process.

Works as get_child_pid/2, but raises an error instead of returning
`{:error, reason}` tuple.