# Membrane.RCPipeline

Remote controlled pipeline - a basic `Membrane.Pipeline` implementation that can be remotely controlled from an external process.

The easiest way to start this pipeline is to use `start_link!/1`
```
  pipeline = Membrane.RCPipeline.start_link!()
```

The controlling process can request the execution of arbitrary
valid `Membrane.Pipeline.Action`:
```
  children = ...
  links = ...
  actions = [{:spec, children++links}]
  Pipeline.exec_actions(pipeline, actions)
```

The controlling process can also subscribe to the messages
sent by the pipeline and later on synchronously await for these messages:
```
# subscribes to message which is sent when the pipeline enters `playing`
Membrane.RCPipeline.subscribe(pipeline, %Message.Playing{})
...
# awaits for the message sent when the pipeline enters :playing playback
Membrane.RCPipeline.await_playing(pipeline)
...
```

`Membrane.RCPipeline` can be used when there is no need for introducing a custom
logic in the `Membrane.Pipeline` callbacks implementation. An example of usage could be running a
pipeline from the elixir script. `Membrane.RCPipeline` sends the following messages:
* `t:Membrane.RCMessage.Playing.t/0` sent when pipeline enters `playing` playback,
* `t:Membrane.RCMessage.StartOfStream.t/0` sent
when one of direct pipeline children informs the pipeline about start of a stream,
* `t:Membrane.RCMessage.EndOfStream.t/0` sent
when one of direct pipeline children informs the pipeline about end of a stream,
* `t:Membrane.RCMessage.Notification.t/0` sent when pipeline
receives notification from one of its children,
* `t:Membrane.RCMessage.Terminated.t/0` sent when the pipeline gracefully terminates.

## start_link/1

Starts the `Membrane.RCPipeline` and links it to the current process. The process
that makes the call to the `start_link/1` automatically becomes the controller process.

## start/1

Does the same as the `start_link/1` but starts the process outside of the current supervision tree.

## await_playing/1

Awaits for the first `t:Membrane.RCMessage.t/0` wrapping the `t:Membrane.RCMessage.Playing.t/0`
It is required to firstly use the `subscribe/2` to subscribe to a given message before awaiting
for that message.

Usage example:
  1) awaiting until the pipeline starts playing:
  ```
  Pipeline.await_playing(pipeline)
  ```

## await_start_of_stream/1

Awaits for the first `t:Membrane.RCMessage.t/0` wrapping the `t:Membrane.RCMessage.StartOfStream.t/0` message
with no further constraints, sent by the process with `pipeline` pid.
It is required to firstly use the `subscribe/2` to subscribe to a given message before awaiting
for that message.

Usage example:
  1) awaiting for the first `start_of_stream` occuring on any pad of any element in the pipeline:
  ```
  Pipeline.await_start_of_stream(pipeline)
  ```

## await_start_of_stream/2

Awaits for the first `t:Membrane.RCMessage.t/0` wrapping the `t:Membrane.RCMessage.StartOfStream.t/0` message
concerning the given `element`, sent by the process with `pipeline` pid.
It is required to firstly use the `subscribe/2` to subscribe to a given message before awaiting
for that message.

Usage example:
  1) awaiting for the first `start_of_stream` occuring on any pad of the `:element_id` element in the pipeline:
  ```
  Pipeline.await_start_of_stream(pipeline, :element_id)
  ```

## await_start_of_stream/3

Awaits for the first `t:Membrane.RCMessage.t/0` wrapping the `t:Membrane.RCMessage.StartOfStream.t/0` message
concerning the given `element` and the `pad`, sent by the process with `pipeline` pid.
It is required to firstly use the `subscribe/2` to subscribe to a given message before awaiting
for that message.

Usage example:
  1) awaiting for the first `start_of_stream` occuring on the `:pad_id` pad of the `:element_id` element in the pipeline:
  ```
  Pipeline.await_start_of_stream(pipeline, :element_id, :pad_id)
  ```

## await_end_of_stream/1

Awaits for the first `t:Membrane.RCMessage.t/0` wrapping the `t:Membrane.RCMessage.EndOfStream.t/0` message
with no further constraints, sent by the process with `pipeline` pid.
It is required to firstly use the `subscribe/2` to subscribe to a given message before awaiting
for that message.

Usage example:
  1) awaiting for the first `end_of_stream` occuring on any pad of any element in the pipeline:
  ```
  Pipeline.await_end_of_stream(pipeline)
  ```

## await_end_of_stream/2

Awaits for the first `t:Membrane.RCMessage.t/0` wrapping the `t:Membrane.RCMessage.EndOfStream.t/0` message
concerning the given `element`, sent by the process with `pipeline` pid.
It is required to firstly use the `subscribe/2` to subscribe to a given message before awaiting
for that message.

Usage example:
  1) awaiting for the first `end_of_stream` occuring on any pad of the `:element_id` element in the pipeline:
  ```
  Pipeline.await_end_of_stream(pipeline, :element_id)
  ```

## await_end_of_stream/3

Awaits for the first `t:Membrane.RCMessage.t/0` wrapping the `t:Membrane.RCMessage.EndOfStream.t/0` message
concerning the given `element` and the `pad`, sent by the process with `pipeline` pid.
It is required to firstly use the `subscribe/2` to subscribe to a given message before awaiting
for that message.

Usage example:
  1) awaiting for the first `end_of_stream` occuring on the `:pad_id` of the `:element_id` element in the pipeline:
  ```
  Pipeline.await_end_of_stream(pipeline, :element_id, :pad_id)
  ```

## await_notification/1

Awaits for the first `t:Membrane.RCMessage.t/0` wrapping the `t:Membrane.RCMessage.Notification.t/0`
message with no further constraints, sent by the process with `pipeline` pid.
It is required to firstly use the `subscribe/2` to subscribe to a given message before awaiting
for that message.

Usage example:
  1) awaiting for the first notification send to any element in the pipeline:
  ```
  Pipeline.await_notification(pipeline)
  ```

## await_notification/2

Awaits for the first `t:Membrane.RCMessage.t/0` wrapping the `t:Membrane.RCMessage.Notification.t/0` message
concerning the given `element`, sent by the process with `pipeline` pid.
It is required to firstly use the `subscribe/2` to subscribe to a given message before awaiting
for that message.

Usage example:
  1) awaiting for the first notification send to the `:element_id` element in the pipeline:
  ```
  Pipeline.await_notification(pipeline, :element_id)
  ```

## await_termination/1

Awaits for the `t:Membrane.RCMessage.t/0` wrapping the `Membrane.RCMessage.Terminated` message,
which is send when the pipeline gracefully terminates.
It is required to firstly use the `subscribe/2` to subscribe to a given message before awaiting
for that message.

Usage example:
  1) awaiting for the pipeline termination:
  ```
  Pipeline.await_termination(pipeline)
  ```

## subscribe/2

Subscribes to a given `subscription_pattern`. The `subscription_pattern` should describe some subset
of elements of `t:Membrane.RCPipeline.Message.t/0` type. The `subscription_pattern`
must be a match pattern.


Usage examples:
1) making the `Membrane.RCPipeline` send to the controlling process `Message.StartOfStream` message
  when any pad of the `:element_id` receives `:start_of_stream` event.

  ```
  subscribe(pipeline, %Message.StartOfStream{element: :element_id, pad: _})
  ```

2) making the `Membrane.RCPipeline` send to the controlling process `Message.Playing` message when the pipeline playback changes to `:playing`

  ```
  subscribe(pipeline, %Message.Playing{})
  ```

## exec_actions/2

Sends a list of `t:Pipeline.Action.t/0` to the given `Membrane.RCPipeline` for execution.

Usage example:
  1) making the `Membrane.RCPipeline` start the `Membrane.ChildrenSpec`
     specified in the action.
  ```
  children = ...
  links = ...
  actions = [{:spec, children++links}]
  Pipeline.exec_actions(pipeline, actions)
  ```