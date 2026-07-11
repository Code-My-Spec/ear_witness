# Kino.Bridge



## generate_token/0

Generates a unique, reevaluation-safe token.

If obtaining the token fails, a unique term is returned
instead.

## put_output/1

Sends the given output as intermediate evaluation result.

## put_output_to/2

Sends the given output as intermediate evaluation result directly
to a specific client.

## put_output_to_clients/1

Sends the given output as intermediate evaluation result directly
to all connected client.

## get_input_value/1

Requests the current value of input with the given id.

Note that the input must be known to Livebook, otherwise
an error is returned.

## get_file_path/1

Requests the file path for the given file id.

## get_file_entry_path/1

Requests the file path for the notebook file with the given name.

## get_file_entry_spec/1

Requests the file spec for the notebook file with the given name.

## reference_object/2

Associates `object` with `pid`.

Any monitoring added to `object` will be dispatched once
all of its associated pids terminate or the associated
cells reevaluate.

See `monitor_object/3` to add a monitoring.

## monitor_object/4

Monitors an existing object to send `payload` to `target`
when all of its associated pids or the associated cells
reevaluate.

It must be called after at least one reference is added
via `reference_object/2`.

## Options

  * `:ack?` - whether the monitoring process wants to
    acknowledge the monitor message. When set to `true`
    the process receives `{payload, reply_to, reply_as}`
    and should do `send(reply_to, reply_as)` once it is
    done. This is useful when cleaning state after the
    object is removed, because Livebook waits for the
    acknowledgement before staring new evaluation.
    Defaults to `false`

## broadcast/3

Broadcasts the given message in Livebook to interested parties.

## send/2

Sends message to the given Livebook process.

## monitor/1

Starts monitoring the given Livebook process.

Provides the same semantics as `Process.monitor/1`.

## get_evaluation_file/0

Returns the file that is currently being evaluated.

## get_app_info/0

Returns information about the running app.

## get_tmp_dir/0

Returns a temporary directory tied to the current runtime.

## get_beam_paths/0

Returns directories with `.beam` files tied to the current runtime.

## monitor_clients/1

Starts monitoring clients presence from the given process.

The monitoring process receives the following messages:

    * `{:client_join, client_id}`

    * `{:client_leave, client_id}`

Returns a list of client ids that are already joined.

## get_user_info/1

Returns user information for the given connected client id.

Errors with `:not_available`, unless the notebook uses a Livebook
Teams hub.

## within_livebook?/0

Checks if the caller is running within Livebook context (group leader).

## get_proxy_handler_child_spec/1

Requests the child spec for proxy handler with the given function.